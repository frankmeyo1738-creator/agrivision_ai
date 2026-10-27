package ai.agrivision.agrivision_ai

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ColorSpace
import androidx.exifinterface.media.ExifInterface
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.nio.FloatBuffer
import java.security.MessageDigest
import kotlin.math.exp

/** A single session, used only by MainActivity's background serial executor. */
class OfflineClassifier(private val context: Context) : AutoCloseable {
    private var session: OrtSession? = null
    private val environment = OrtEnvironment.getEnvironment()
    private lateinit var manifest: JSONObject
    private val assetRoot = "flutter_assets/assets/models/"
    private val labels = listOf("Tomato Healthy", "Tomato Early Blight", "Tomato Late Blight", "Tomato Bacterial Spot", "Tomato Leaf Mold", "Maize Healthy", "Maize Common Rust", "Maize Gray Leaf Spot", "Maize Northern Leaf Blight", "Potato Healthy", "Potato Early Blight", "Potato Late Blight", "Bell Pepper Healthy", "Bell Pepper Bacterial Spot")

    fun load() {
        if (session != null) return
        manifest = JSONObject(context.assets.open(assetRoot + "model_manifest.json").bufferedReader().use { it.readText() })
        require(manifest.getInt("format_version") == 1) { "Incompatible model manifest." }
        val preprocessing = manifest.getJSONObject("preprocessing")
        require(preprocessing.getInt("version") == 1 && preprocessing.getInt("image_size") == 224 &&
            preprocessing.getInt("resize_short_edge") == 256 && preprocessing.getString("crop") == "center" &&
            preprocessing.getString("interpolation") == "bilinear" && preprocessing.getString("color_mode") == "RGB" &&
            preprocessing.getBoolean("exif_transpose")) { "Preprocessing contract mismatch." }
        for ((key, expected) in listOf("mean" to listOf(0.485, 0.456, 0.406), "std" to listOf(0.229, 0.224, 0.225))) {
            val values = preprocessing.getJSONArray(key)
            require(values.length() == 3 && (0..2).all { values.getDouble(it) == expected[it] })
        }
        val bundledLabels = manifest.getJSONArray("labels")
        require((0 until bundledLabels.length()).map { bundledLabels.getString(it) } == labels) { "Incorrect class ordering." }
        for (label in labels) {
            val guidance = manifest.getJSONObject("guidance").getJSONObject(label)
            require(guidance.getString("description").isNotBlank() && guidance.getJSONArray("management").length() > 0)
        }
        val bytes = context.assets.open(assetRoot + "multicrop_mobilenet_v3_small.onnx").use { it.readBytes() }
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
        require(digest == manifest.getString("model_sha256")) { "The bundled model failed its integrity check." }
        OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)
            options.setInterOpNumThreads(1)
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            val created = environment.createSession(bytes, options)
            try {
                val input = created.inputInfo["images"]?.info as? TensorInfo
                val output = created.outputInfo["logits"]?.info as? TensorInfo
                require(input?.shape?.contentEquals(longArrayOf(1, 3, 224, 224)) == true)
                require(output?.shape?.contentEquals(longArrayOf(1, 14)) == true)
                session = created
            } catch (e: Exception) {
                created.close()
                throw e
            }
        }
    }

    fun health(): Map<String, Any> {
        load()
        return mapOf("status" to "ok", "model_loaded" to true, "class_labels" to labels,
            "supported_crops" to listOf("Tomato", "Maize", "Potato", "Bell Pepper"),
            "test_accuracy" to manifest.getJSONObject("evaluation").getDouble("accuracy"),
            "macro_f1" to manifest.getJSONObject("evaluation").getDouble("f1_macro"))
    }

    fun decode(data: ByteArray): LeafPreprocessor.RgbImage {
        require(data.isNotEmpty()) { "Image is empty." }
        require(data.size <= 10 * 1024 * 1024) { "Choose an image smaller than 10 MiB." }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        require(bounds.outMimeType in setOf("image/jpeg", "image/png", "image/webp")) { "Use a JPEG, PNG or WebP photo." }
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Image cannot be decoded." }
        require(bounds.outWidth.toLong() * bounds.outHeight <= 20_000_000) { "Choose an image under 20 megapixels." }
        require(bounds.outWidth <= 8192 && bounds.outHeight <= 8192) { "Choose a photo with edges under 8192 pixels." }
        require(maxOf(bounds.outWidth, bounds.outHeight) <= minOf(bounds.outWidth, bounds.outHeight) * 16L) { "Use a regular leaf photo, not a panorama." }
        val options = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inScaled = false
            inPremultiplied = false // Drop alpha without compositing onto white/black.
            if (android.os.Build.VERSION.SDK_INT >= 26) inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.SRGB)
        }
        val bitmap = BitmapFactory.decodeByteArray(data, 0, data.size, options)
            ?: throw IllegalArgumentException("Image cannot be decoded.")
        val pixels = IntArray(bitmap.width * bitmap.height)
        val image = try {
            bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
            LeafPreprocessor.RgbImage(bitmap.width, bitmap.height, pixels)
        } finally { bitmap.recycle() }
        val orientation = try {
            ExifInterface(ByteArrayInputStream(data)).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
        } catch (_: java.io.IOException) { 1 }
        return LeafPreprocessor.orient(image, orientation)
    }

    fun logits(tensor: FloatArray): FloatArray {
        load()
        require(tensor.size == 3 * 224 * 224)
        OnnxTensor.createTensor(environment, FloatBuffer.wrap(tensor), longArrayOf(1, 3, 224, 224)).use { input ->
            session!!.run(mapOf("images" to input)).use { outputs ->
                @Suppress("UNCHECKED_CAST")
                val value = (outputs[0].value as Array<FloatArray>)[0].clone()
                require(value.size == 14 && value.all { it.isFinite() }) { "Model output is invalid." }
                return value
            }
        }
    }

    fun predict(data: ByteArray): Map<String, Any> {
        val values = logits(LeafPreprocessor.tensor(decode(data)))
        val scores = probabilities(values)
        val indices = scores.indices.sortedWith(compareByDescending<Int> { scores[it] }.thenBy { it }).take(3)
        val winner = labels[indices.first()]
        return mapOf(
            "predicted_class" to winner,
            "confidence" to scores[indices.first()],
            "top_predictions" to indices.map { mapOf("class" to labels[it], "confidence" to scores[it]) },
            "disease_information" to jsonMap(manifest.getJSONObject("guidance").getJSONObject(winner)),
            "confidence_note" to manifest.getString("confidence_note")
        )
    }

    companion object {
        fun probabilities(logits: FloatArray): DoubleArray {
            val peak = logits.maxOrNull()!!.toDouble()
            val values = DoubleArray(logits.size) { exp(logits[it] - peak) }
            val sum = values.sum()
            return DoubleArray(values.size) { values[it] / sum }
        }
        private fun jsonMap(json: JSONObject): Map<String, Any> = json.keys().asSequence().associateWith { key ->
            when (val value = json.get(key)) {
                is org.json.JSONArray -> (0 until value.length()).map { value.getString(it) }
                else -> value
            }
        }
    }

    override fun close() { session?.close(); session = null }
}

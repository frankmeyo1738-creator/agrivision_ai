package ai.agrivision.agrivision_ai

import android.content.pm.PackageManager
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs

@RunWith(AndroidJUnit4::class)
class OfflineInferenceTest {
    @Test fun actualCheckpointPreprocessingAndPredictionsMatchPython() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val assets = instrumentation.context.assets
        val cases = JSONArray(assets.open("verification/cases.json").bufferedReader().use { it.readText() })
        val results = JSONArray()
        OfflineClassifier(context).use { engine ->
            engine.load()
            for (index in 0 until cases.length()) {
                val case = cases.getJSONObject(index)
                val name = case.getString("file")
                val bytes = assets.open("verification/$name").use { it.readBytes() }
                val expected = assets.open("verification/$name.f32").use { it.readBytes() }
                val floatBuffer = ByteBuffer.wrap(expected).order(ByteOrder.LITTLE_ENDIAN).asFloatBuffer()
                val golden = FloatArray(floatBuffer.remaining()).also { floatBuffer.get(it) }
                val actual = LeafPreprocessor.tensor(engine.decode(bytes))
                val tensorError = actual.indices.maxOf { abs(actual[it] - golden[it]).toDouble() }
                assertTrue("Tensor $name: $tensorError", tensorError <= case.getDouble("tensor_tolerance"))
                // Lossless decoded images isolate resize/crop/RGB math from JPEG decoders.
                val decoded = assets.open("verification/" + case.getString("decoded_png")).use { it.readBytes() }
                val losslessTensor = LeafPreprocessor.tensor(engine.decode(decoded))
                val losslessError = losslessTensor.indices.maxOf { abs(losslessTensor[it] - golden[it]).toDouble() }
                assertTrue("Lossless tensor $name: $losslessError", losslessError <= 1e-6)
                val sameInputLogits = engine.logits(golden)
                val expectedLogits = case.getJSONArray("pytorch_logits")
                val graphError = sameInputLogits.indices.maxOf { abs(sameInputLogits[it] - expectedLogits.getDouble(it)) }
                assertTrue("Android graph $name: $graphError", graphError <= 1e-4)
                val start = System.nanoTime()
                val prediction = engine.predict(bytes)
                val elapsedMs = (System.nanoTime() - start) / 1e6
                val probabilities = OfflineClassifier.probabilities(engine.logits(actual))
                val expectedProbabilities = case.getJSONArray("pytorch_probabilities")
                val probabilityError = probabilities.indices.maxOf { abs(probabilities[it] - expectedProbabilities.getDouble(it)) }
                assertTrue("Probability $name: $probabilityError", probabilityError <= case.getDouble("probability_tolerance"))
                assertEquals("Top one $name", case.getInt("top_index"), probabilities.indices.maxBy { probabilities[it] })
                @Suppress("UNCHECKED_CAST")
                val information = prediction["disease_information"] as Map<String, Any>
                assertTrue((information["description"] as String).isNotEmpty())
                assertTrue((information["management"] as List<*>).isNotEmpty())
                assertTrue((prediction["top_predictions"] as List<*>).size == 3)
                results.put(JSONObject().put("file", name).put("purpose", case.getString("purpose"))
                    .put("max_tensor_error", tensorError).put("max_lossless_tensor_error", losslessError)
                    .put("max_logit_error_same_input", graphError).put("max_probability_error", probabilityError)
                    .put("top_one_matches", true).put("prediction_elapsed_ms", elapsedMs))
            }
        }
        val report = JSONObject().put("device", android.os.Build.MODEL).put("sdk", android.os.Build.VERSION.SDK_INT)
            .put("airplane_mode", android.provider.Settings.Global.getInt(context.contentResolver, "airplane_mode_on", 0))
            .put("purpose", "runtime parity, not accuracy").put("passed", true).put("cases", results)
        context.openFileOutput("android_verification.json", 0).use { it.write(report.toString(2).toByteArray()) }
        java.io.File(context.getExternalFilesDir(null), "phase4_android_verification.json").writeText(report.toString(2))
        Log.i("AgriVisionVerification", report.toString())
    }

    @Test fun invalidImagesFailWithoutProducingPredictions() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        OfflineClassifier(context).use { engine ->
            for (bytes in listOf(byteArrayOf(), byteArrayOf(1, 2, 3), ByteArray(10 * 1024 * 1024 + 1))) {
                try { engine.predict(bytes); fail("Invalid image was accepted") }
                catch (_: IllegalArgumentException) { /* expected */ }
            }
        }
    }
}

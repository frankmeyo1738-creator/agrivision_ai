package ai.agrivision.agrivision_ai

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var classifier: OfflineClassifier? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai.agrivision/offline")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method !in setOf("health", "predict")) { result.notImplemented(); return@setMethodCallHandler }
            val bytes = call.argument<ByteArray>("bytes")
            worker.execute {
                try {
                    val engine = classifier ?: OfflineClassifier(applicationContext).also { classifier = it }
                    val output = if (call.method == "health") {
                        engine.health()
                    } else {
                        require(bytes != null) { "No image was selected." }
                        engine.predict(bytes)
                    }
                    main.post { result.success(output) }
                } catch (e: Exception) {
                    val message = if (e is IllegalArgumentException) e.message ?: "Invalid image or model." else "On-device model could not run. Reopen the app or reinstall the APK."
                    main.post { result.error("OFFLINE_INFERENCE", message, null) }
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        channel?.setMethodCallHandler(null)
        worker.execute { classifier?.close(); classifier = null }
        worker.shutdown()
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

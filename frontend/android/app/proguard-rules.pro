# ONNX Runtime JNI constructs NodeInfo, TensorInfo and value wrappers by class/
# constructor name. Keep its Java API intact; debug tests do not exercise R8.
-keep class ai.onnxruntime.** { *; }

# Keep native inference entry points stable for release APK parity instrumentation.
-keep class ai.agrivision.agrivision_ai.OfflineClassifier { *; }
-keep class ai.agrivision.agrivision_ai.LeafPreprocessor** { *; }

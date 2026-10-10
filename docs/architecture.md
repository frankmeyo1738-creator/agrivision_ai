# Architecture

AgriVision AI is a local macOS application with a separate Python inference server.
Phase 1 implements the Python path and a minimal Flutter application foundation.

```text
PlantVillage color folders + optional leaf IDs
                 |
      deterministic grouped split manifests
                 |
  Colab: ImageNet MobileNetV3-Small + five-class head
                 |
  best_model.pt + class_mapping.json + evaluation artifacts
                 |
  FastAPI on 127.0.0.1:8000 -> shared CPU inference engine
                 |
  Flutter desktop (HTTP multipart integration in Phase 2)
```

`backend/app/ml/classes.py` fixes the class indices, and `model.py` owns the
architecture and transforms. Training uses these same modules as serving. Model
loading never downloads pretrained weights and never retrains. The service loads
once in the FastAPI lifespan. Missing or invalid weights leave the service available
for health checks while valid prediction requests return HTTP 503.

The inference engine also runs independently through
`python -m backend.app.ml.inference IMAGE --model-dir models`. It performs bounded
decoding, RGB/EXIF handling, deterministic preprocessing, CPU inference mode, and
top-three softmax ranking. A lock serializes model forward passes; inference is
offloaded from the asynchronous HTTP loop. Four CPU threads are used by the app.

API schema: `GET /health` reports liveness, model readiness, and an actionable model
message. `POST /predict` accepts the multipart field `image`, returns the winning
class and probability, three rankings, educational disease guidance with sources,
and a confidence note. Scores are fractions in [0, 1]; a future UI should format
them as percentages. The top-three scores need not sum to one because two scores
are omitted.

Upload limits: 10 MiB compressed data, 20 million decoded pixels, JPEG/PNG/WebP.
Content type and actual decoded format are checked. Errors: 400 invalid image,
413 too large, 415 unsupported type, 422 missing field, 503 unavailable model,
500 sanitized inference failure. Internal details go only to server logs. Valid
image validation precedes the unavailable-model error. The default deployment
is local loopback with no authentication or cloud infrastructure.

Flutter includes Material 3 forest/emerald/off-white theme foundations, a configurable
API URL, `http`, `file_selector`, and both debug/release macOS entitlements for
outgoing networking and user-selected read-only files. The full dashboard,
detection, results, and model information screens are deliberately Phase 2 work.

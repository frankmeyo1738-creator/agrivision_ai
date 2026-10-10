Planned Phase 2 folders: `dashboard/`, `detection/`, `results/`, and `model_info/`.

Use ordinary StatefulWidget/ValueNotifier state where needed. HTTP multipart upload
will use `http`; local image selection will use `file_selector`. No detection UI or
mock predictions are implemented in Phase 1. Keep API response parsing in a shared
service and show the backend's informative unavailable-model response.

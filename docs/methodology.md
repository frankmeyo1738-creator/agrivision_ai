# Training and evaluation methodology

The five class indices are fixed independently of folder sorting:

| Index | Display label | PlantVillage category |
| --- | --- | --- |
| 0 | Tomato Healthy | Tomato___healthy |
| 1 | Tomato Early Blight | Tomato___Early_blight |
| 2 | Tomato Late Blight | Tomato___Late_blight |
| 3 | Tomato Bacterial Spot | Tomato___Bacterial_spot |
| 4 | Tomato Leaf Mold | Tomato___Leaf_Mold |

Torchvision MobileNetV3-Small starts with `IMAGENET1K_V1` weights. Its final linear
layer is replaced with five outputs. Feature extractor parameters are frozen;
feature BatchNorm layers remain in evaluation mode during head training, preventing
running-statistic drift. The full classifier head trains with cross entropy and
AdamW. Training logits feed cross entropy directly; serving applies softmax.
The architecture follows [Torchvision's official builder](https://docs.pytorch.org/vision/stable/models/generated/torchvision.models.mobilenet_v3_small.html).

Defaults: seed 42, 70/15/15 grouped class-stratified split, eight maximum epochs,
batch size 32, learning rate 0.001, weight decay 0.0001, early stopping after three
epochs without lower validation loss, zero loader workers. `auto` selects CUDA
when available, otherwise CPU; explicit `cpu` and `cuda` are supported. Apple
Silicon serving uses CPU to keep deployment predictable. No MPS dependency.

All images receive EXIF orientation correction and RGB conversion. Evaluation and
inference resize the shorter edge to 256 with bilinear interpolation, center crop
224×224, convert to [0, 1] tensors, and normalize with ImageNet mean
[0.485, 0.456, 0.406] and standard deviation [0.229, 0.224, 0.225]. Training alone
uses random resized cropping, horizontal flips, rotation, and mild color jitter.
Python, NumPy, Torch, and loader workers are seeded. cuDNN benchmark is disabled;
deterministic algorithms are requested with warnings for unsupported operations.
Exact bitwise reproduction across hardware/software versions is not guaranteed.

The best validation-loss checkpoint is reloaded before the test set is used. Test
labels never select epochs or hyperparameters. `evaluation.json` records actual
sample count, accuracy, macro precision/recall/F1, per-class scores and support,
weighted averages, confusion matrix, and its class order. Matrix rows are true
labels and columns are predictions. Training history/curves and a confusion matrix
PNG are generated from observed values. No benchmark scores are prefilled.

The split manifest and dataset report are preserved beside weights for audit. Pixel
hashes detect exact decoded duplicates; union-find merges overlapping filename,
metadata, and pixel groups before approximate stratification. Images within a
group cannot cross any partition. Conflicting group labels cause preparation to
fail. Known related-image groups matter more than matching the requested percentages
exactly. Unknown leaf relations and recompressed near duplicates remain limitations.
See [dataset handling](dataset.md) for formats, provenance, and licensing.

PlantVillage contains largely controlled leaf photographs. Held-out performance on
this dataset does not establish performance in Zambian fields or on different
cameras, lighting, backgrounds, pests, mixed infections, or nutritional stress.
The classifier always ranks these five classes and has no out-of-distribution
detector. It cannot prove an upload depicts a tomato leaf. A softmax confidence
score is not diagnostic certainty or a calibrated probability of disease. Do not
present it as a confirmed diagnosis. Significant symptoms require local expert
confirmation; future field-data validation and calibration are separate work.

Dataset-free tests use explicitly synthetic tiny images and temporary random
checkpoints to verify mechanics, serialization, and API behavior. These fixtures
are never exported to `models/`, never used as demo predictions, and their results
are not ML evaluation results. The project remains untrained until a genuine
PlantVillage training run completes.

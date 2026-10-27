"""Create Android test-only assets and preprocessing goldens from fixed photos.

Synthetic patterns exercise mechanics only; never report these as disease data.
The generated Android instrumentation assets are excluded from the release APK.
"""

import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from PIL import Image

from backend.app.ml.images import decode_image
from backend.app.ml.inference import InferenceEngine


def main():
    root = Path("artifacts/android_verification/images")
    fixed = json.loads((root / "manifest.json").read_text())["images"]
    assets = Path("frontend/android/app/src/androidTest/assets/verification")
    assets.mkdir(parents=True, exist_ok=True)
    engine = InferenceEngine(Path("models"))
    engine.load()
    torch.set_num_threads(2)
    cases = []
    for case in fixed:
        source = root / case["path"]
        assert hashlib.sha256(source.read_bytes()).hexdigest() == case["sha256"]
        (assets / source.name).write_bytes(source.read_bytes())
        cases.append((source.name, "real_leaf_jpeg", 0.04, 0.01))
        png_name = source.stem + ".png"
        decode_image(source.read_bytes()).save(assets / png_name)
        cases.append((png_name, "lossless_leaf", 1e-6, 1e-5))
    for width, height in [(319, 257), (257, 319), (47, 32), (999, 301), (302, 1001)]:
        y, x = np.indices((height, width))
        rgb = np.stack(
            [(x * 13 + y * 7) % 256, (x * 3 + y * 19) % 256, (x * 31 + y * 5) % 256], axis=-1
        ).astype("uint8")
        name = f"pattern_{width}_{height}.png"
        Image.fromarray(rgb).save(assets / name)
        cases.append((name, "synthetic_geometry", 1e-6, 1e-5))
    pattern = Image.open(assets / "pattern_319_257.png")
    for orientation in range(1, 9):
        exif = Image.Exif()
        exif[274] = orientation
        name = f"orientation_{orientation}.jpg"
        pattern.save(assets / name, quality=95, exif=exif)
        cases.append((name, "synthetic_exif", 0.04, 0.01))
    for mode in ("L", "RGBA"):
        image = pattern.convert(mode)
        if mode == "RGBA":
            image.putalpha(
                Image.fromarray(
                    np.arange(319 * 257, dtype=np.uint32).reshape(257, 319).astype("uint8")
                )
            )
        name = f"mode_{mode}.png"
        image.save(assets / name)
        cases.append((name, "synthetic_color_mode", 1e-6, 1e-5))
    pattern.save(assets / "lossless.webp", lossless=True)
    cases.append(("lossless.webp", "synthetic_webp", 1e-6, 1e-5))
    results = []
    for name, purpose, tensor_limit, probability_limit in cases:
        data = (assets / name).read_bytes()
        image = decode_image(data)
        tensor = engine.transform(image).unsqueeze(0)
        with torch.inference_mode():
            logits = engine.model(tensor)[0]
        tensor.numpy().astype("<f4").tofile(assets / (name + ".f32"))
        # Separate lossless decoded-pixel goldens test EXIF mapping/filtering
        # independent of platform JPEG decoder differences.
        decoded_name = name + ".decoded.png"
        image.save(assets / decoded_name)
        results.append(
            {
                "file": name,
                "purpose": purpose,
                "sha256": hashlib.sha256(data).hexdigest(),
                "tensor_tolerance": tensor_limit,
                "probability_tolerance": probability_limit,
                "pytorch_logits": logits.tolist(),
                "pytorch_probabilities": torch.softmax(logits, dim=0).tolist(),
                "decoded_png": decoded_name,
                "top_index": int(logits.argmax()),
            }
        )
    (assets / "cases.json").write_text(json.dumps(results, indent=2) + "\n")
    Path("docs/android/preprocessing_cases.json").write_text(json.dumps(results, indent=2) + "\n")
    print(
        f"Prepared {len(results)} Android cases: real leaf photos + synthetic mechanics; "
        "no disease accuracy metric."
    )


if __name__ == "__main__":
    main()

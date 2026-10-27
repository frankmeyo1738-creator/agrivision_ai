"""Opt-in download of only the five provenance-recorded conversion test photos."""

import hashlib
import json
import urllib.request
from pathlib import Path


def main():
    report = json.loads(Path("docs/android/conversion_verification.json").read_text())
    root = Path("artifacts/android_verification/images")
    root.mkdir(parents=True, exist_ok=True)
    images = []
    for case in report["cases"]:
        path = root / Path(case["path"]).name
        if path.exists():
            data = path.read_bytes()
        else:
            with urllib.request.urlopen(case["source_url"], timeout=30) as stream:
                data = stream.read(1024 * 1024 + 1)
            if len(data) > 1024 * 1024:
                raise ValueError("Unexpectedly large verification image.")
            if hashlib.sha256(data).hexdigest() != case["sha256"]:
                raise ValueError(
                    "Upstream verification image changed; do not replace the fixed set."
                )
            path.write_bytes(data)
        if hashlib.sha256(data).hexdigest() != case["sha256"]:
            raise ValueError(f"Local verification image changed: {path}")
        images.append(
            {key: case[key] for key in ("path", "sha256", "source_url", "source_class", "purpose")}
        )
    (root / "manifest.json").write_text(json.dumps({"images": images}, indent=2) + "\n")
    print("Five fixed-set photos available; no bulk dataset acquisition.")


if __name__ == "__main__":
    main()

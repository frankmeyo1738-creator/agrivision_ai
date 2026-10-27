"""Package isolated Phase 4 source and metadata, excluding images and models."""

import argparse
import zipfile
from pathlib import Path


def package(output):
    root = Path(__file__).resolve().parents[2]
    source_files = list((root / "training/multicrop").glob("*.py"))
    source_files += list((root / "training/multicrop").glob("*.json"))
    source_files += list((root / "training/multicrop").glob("*.ipynb"))
    source_files += [root / name for name in (
        "backend/__init__.py", "backend/app/__init__.py", "backend/app/ml/__init__.py",
        "backend/app/ml/model.py", "backend/app/ml/classes.py", "training/__init__.py",
        "training/prepare_dataset.py", "docs/PHASE4_COLAB.md")]
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source_files):
            archive.write(path, path.relative_to(root))
    print(f"Source-only Colab handoff: {output.resolve()} ({output.stat().st_size:,} bytes)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("artifacts/agrivision_phase4_colab_source.zip"))
    package(parser.parse_args().output)

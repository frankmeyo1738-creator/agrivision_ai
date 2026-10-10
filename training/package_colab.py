"""Package only the small Python sources and notebook for upload to Google Colab."""

import argparse
import zipfile
from pathlib import Path


def package_sources(root: Path, output: Path) -> None:
    files = [
        root / name for name in ("README.md", "LICENSE", "pyproject.toml", "requirements-dev.txt")
    ]
    for directory in ("backend", "training", "docs"):
        files.extend(
            path
            for path in (root / directory).rglob("*")
            if path.is_file() and path.suffix in {".py", ".yaml", ".txt", ".md", ".ipynb"}
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(files):
            if path.is_file():
                archive.write(path, path.relative_to(root))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output", type=Path, default=Path("artifacts/agrivision_colab_source.zip")
    )
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    package_sources(root, args.output)
    print(f"Colab source package: {args.output.resolve()}")


if __name__ == "__main__":
    main()

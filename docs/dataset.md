# Dataset source, terms, and preparation

Use the original [PlantVillage repository](https://github.com/spMohanty/PlantVillage-Dataset)
by Mohanty, Hughes, and Salathé, and cite their
[2016 research paper](https://doi.org/10.3389/fpls.2016.01419). This project uses only
the five selected tomato categories from `raw/color`; it never mixes the grayscale
or segmented versions of the same images into the training pool.

The author's [Hugging Face dataset card](https://huggingface.co/datasets/mohanty/PlantVillage)
labels the dataset CC BY-SA 3.0. The upstream loader describes that license as an
assumption, so retain this caveat and verify the terms for the copy you obtain before
redistribution. The project's MIT license applies to our code, not the dataset or
third-party ImageNet weights. No dataset is bundled or downloaded during Phase 1.

To obtain only the relevant folders yourself (Git and internet required):

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/spMohanty/PlantVillage-Dataset.git data/PlantVillage-Dataset
git -C data/PlantVillage-Dataset sparse-checkout set raw/color/Tomato___healthy raw/color/Tomato___Early_blight raw/color/Tomato___Late_blight raw/color/Tomato___Bacterial_spot raw/color/Tomato___Leaf_Mold leaf_grouping
```

The root-level `leaf-map.json` is retained by Git's cone-mode sparse checkout.
Inspect and retain it; the preparer auto-discovers root or `leaf_grouping/` copies
in the dataset directory and its two parent levels. Record the source revision with
`git -C data/PlantVillage-Dataset rev-parse HEAD`. The Colab notebook does this and
saves source provenance. If sparse download is unavailable, manually obtain the
same five original folders and grouping metadata and supply their directory.

From the project root:

```sh
python -m training.prepare_dataset --dataset-root data/PlantVillage-Dataset --output-dir artifacts/prepared
```

The root can be the original repository, its `raw/color` directory, a `color` folder,
or a directory containing class folders directly. A `PlantVillage/` child is also
recognized. Case, spaces, and underscores are normalized, so `Tomato_Early_blight`
and `Tomato___Early_blight` both work. If several variant directories exist, select
the color folder explicitly. Previously split exports should be consolidated into
one original pool only when their provenance and grouping are understood.

Preparation validates all five classes and decodes every supported image, records
per-class counts, and writes `class_mapping.json`, `split_manifest.json`, and
`dataset_report.json`. It fails on corrupt images, missing classes, conflicting
group labels, or fewer than three independent groups per class. It writes manifests
only, leaving source images unchanged. `--seed 42 --ratios 0.70 0.15 0.15` overrides
the defaults; `--leaf-groups FILE.json` selects metadata explicitly.

Grouping uses exact RGB pixel SHA-256, a filename source identifier (stripped UUID
prefix, `copy`, `aug`, `rotated`, `flip`, and `_final_masked` suffixes), and supplied
leaf IDs. For custom data, use JSON such as:

```json
{
  "Tomato___healthy/image01.jpg": "leaf-A",
  "image02.jpg": "leaf-A",
  "rs_early.b 7030": "leaf-B"
}
```

Keys may be root-relative paths, filenames, stems, or normalized original source
identifiers after `___`. Values are a group ID string. Official `leaf-map.json`
values may be lists; single IDs or one unique matching category are accepted.
Ambiguity causes an error requiring corrected metadata. Explicit leaf IDs should
be globally unique (include crop/class prefixes when necessary).

All grouping relationships are merged transitively. The per-class greedy allocator
minimizes count deviations while guaranteeing every class appears in all three
splits. Large groups make ratios approximate. The report states metadata coverage,
exact duplicate counts, and independent group counts. Near-duplicate detection is
limited: recompressed or renamed related images need leaf metadata or a manual
audit. Unknown related leaves may remain; do not claim all biological leakage has
been eliminated. Duplicate copies are kept in the same group and can weight metrics;
report their counts and consider deduplicating before the final academic run.

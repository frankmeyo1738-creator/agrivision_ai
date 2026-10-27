# AgriVision AI — multi-crop dataset research

Research date: **10 October 2026**. Scope: tomato, potato, maize, pepper, cabbage and collard greens; a future **fully offline Android** classifier based on MobileNetV3-Small.

## Decision

Use a **small, provenance-preserving combination of original sources**, rather than indiscriminately merging foundation datasets. PlantVillage provides substantial classification coverage for tomato, potato diseases, maize and **bell pepper**. Add independently collected, expert-labelled field images; consider audited PlantDoc images for domain diversity. Cabbage disease coverage needs an original-image inventory and additional collection. **No sufficient collard-specific disease or pest-damage image collection was verified.**

PlantWild is useful for noncommercial research, but its NC/ND terms require attention before product use. PlantSeg's published release is **7,774 images**, not the older 11,400+ headline. Neither LeafNet nor Agri-Foundation-145k establishes independent new image coverage just by being large.

This report establishes published and manifest-level availability, not a completed image-quality, duplicate or field-performance audit. It authorizes no acquisition or training. No full image archive was downloaded; only public pages, file listings, ZIP central-directory metadata and PlantSeg's small metadata CSV were inspected. Existing model files, training code and Flutter application were not changed.

## Evidence and sufficiency rules

- **Verified manifest count**: complete upstream file listing or archive directory; images were not decoded. Counts are files, not distinct plants or independently validated diagnoses.
- **Publisher-reported**: dataset owner or original paper states the count; not independently recounted here.
- **Unknown**: information was absent, inaccessible or not established for the selected release. Unknown is not zero.
- **Quantity-qualified for a pilot**: at least **300 source image files for the exact crop-condition label**, without counting generated augmentations toward that threshold. This is an engineering screening rule, not a scientifically universal minimum. A nominal 70/15/15 split would leave about 210 training images, but grouped splitting can change this.
- **Training-ready** additionally requires rights confirmation, unique-original counting, crop/pathology review, and a grouped split with adequate held-out examples. **No new combination is certified training-ready by this metadata-only research.** Field deployment additionally requires independent local field testing.

Reported dataset sizes below are hosted/compressed bytes or host-displayed totals, not estimates of extracted disk usage. MB/GB use decimal units unless stated otherwise. Full totals are never divided by class count to invent per-class coverage.

## Named dataset comparison

| Dataset / selected release | Available images and classes | Crop coverage relevant to AgriVision | Healthy / pest coverage | Capture and resolution | Annotation and suitability for MobileNetV3-Small |
|---|---|---|---|---|---|
| **PlantVillage**, original RGB | Owner headline 54,306; current HF example splits total 54,305; 38 crop-condition classes | Tomato, potato, maize, bell pepper; no cabbage/collard | Crop-specific healthy classes; tomato two-spotted spider-mite damage | Controlled detached leaves; paper preprocessing 256×256 | Image classification labels and physical-leaf grouping; directly suitable after RGB/224 preprocessing; field domain gap |
| **PlantDoc**, original classification GitHub | Paper 2,598; current manifest **2,578**, 28 folders across train/test | Tomato, potato, maize, bell pepper; no cabbage/collard folders | Several healthy leaf labels; only 2 spider-mite files in current training tree | Internet/field-style photos; variable resolution, exact range not verified upstream | Image-level labels; separate detection repository provides boxes; ambiguous leaf-spot/rust labels require review |
| **PlantWild v1**, official archive | **18,542**, 89 classes (56 diseased, 33 healthy) | All first five target crops; no collard folder | Healthy crop labels; no dedicated target-crop pest-damage class verified | Web-sourced natural backgrounds; exact resolution range unknown | Cross-reviewed labels, class text prompts and source URLs; extract image labels, no text encoder needed |
| **PlantWild v2**, official archive | **11,488**, 115 disease-condition directories | Tomato, potato, maize, bell pepper, cabbage; no collard | **No healthy directory**; no dedicated pest class verified | Natural/web imagery; exact resolution range unknown | Expert refinement reported; image classification usable; generic rust and non-leaf symptoms need screening |
| **PlantSeg**, DOI 17719108 | **7,774 disease JPEGs**, 115 classes, 34 hosts; masks are additional files, not new images | Same five; no collard host | No healthy images in this release; no dedicated target pest class | Web/natural scenes; CSV width 93–6,000, height 87–5,408 pixels | Class labels, lesion masks, boxes, metadata; use RGB labels for classification; masks can guide training crops, no segmentation decoder required at inference |
| **LeafNet**, Project-AgML public release | **121,337 public rows**; paper describes 186,000 images, 97 classes, 22 crops | Paper includes tomato, potato, maize, pepper and separately chili pepper; no cabbage/collard in crop table | Healthy and mite conditions in full corpus; public per-class breakdown unknown | Mixed public/in-house imagery, majority field claimed; native resolution range unknown | Image-caption/VQA-oriented packaging; extract and validate explicit crop-condition labels rather than treating captions as ground truth automatically |
| **Agri-Foundation-145k**, HF v1 | Publisher claims **144,751**, 215 unified classes; viewer unavailable | Sources cover first five; exact selected-release crop/class inventory not verified | Healthy classes claimed; target pest-class counts unknown | Mixed controlled and natural; native resolution range unknown | Folder labels and provenance CSV claimed; file-integrity validation is not pathology validation; audit fuzzy label merging |
| **Arkansas Plant Disease Database** | >800 images reported in 2022; current clinic says thousands; no exact current inventory | Tomato, potato, corn, pepper, cabbage listed; collard category not verified | Infectious and physiological disorders; no systematic healthy or pest-damage class inventory | Diagnostic reference photos, varied tissues/settings; resolution range unknown | Expert diagnostic context and photo credits; useful reference, not a ready labelled training corpus |

### Official sources, downloads, size, rights and overlap

| Dataset | Official source / download | Storage size verified here | License / redistribution status | Duplication risks |
|---|---|---|---|---|
| PlantVillage | [Author repository](https://github.com/spMohanty/PlantVillage-Dataset), [author HF release](https://huggingface.co/datasets/mohanty/PlantVillage), [original study](https://www.frontiersin.org/journals/plant-science/articles/10.3389/fpls.2016.01419/full) | HF displays 2.2 GB across hosted configurations; 19 relevant RGB classes sum **422,448,413 image bytes** | HF tag CC BY-SA 3.0; [loader](https://github.com/spMohanty/PlantVillage-Dataset/blob/master/plant_village.py) explicitly describes this as an assumption to verify. Preserve attribution and resolve original image rights before redistribution | RGB/grayscale/segmented versions share leaves; New Plant Diseases augmented versions, LeafNet and Agri-Foundation may reuse originals |
| PlantDoc | [Classification](https://github.com/pratikkayal/PlantDoc-Dataset), [detection](https://github.com/pratikkayal/PlantDoc-Object-Detection-Dataset), [paper](https://arxiv.org/abs/1911.10317) | Current train/test image tree **996,322,499 bytes**; Git history excluded | Upstream CC BY 4.0; web-image provenance still requires checking, especially redistribution of individual photos | Cropped/detection/classification releases are related; web-source overlap with PlantWild/PlantSeg possible; included in Agri-Foundation |
| PlantWild v1 | [Author project](https://tqwei05.github.io/PlantWild/), [official HF archives](https://huggingface.co/datasets/uqtwei2/PlantWild/tree/main), project also links Drive/UQRDM | `plantwild.zip`: HF displays **2.71 GB** | CC BY-NC-ND 4.0 | v2 is a refinement, not an independent acquisition; overlap with PlantSeg and web collections must be measured |
| PlantWild v2 | [Version page](https://tqwei05.github.io/PlantWild/access_v2), same official HF `plantwild_v2.zip` | HF displays **1.64 GB** | CC BY-NC-ND 4.0 | Do not add v1 + v2 counts as unique images; same research family as PlantSeg |
| PlantSeg | [Authors' code/old README](https://github.com/tqwei05/PlantSeg), [published paper](https://www.nature.com/articles/s41597-025-06513-4.pdf), [selected Zenodo release](https://zenodo.org/records/17719108) | API `plantseg.zip`: **1,057,281,724 bytes** | Record CC BY-NC 4.0; CSV lists **7,741 CC-BY-NC and 33 CC0** images; version detail still needs per-source checking | Project describes its relationship to PlantWild; masks, boxes and original photos must remain in the same split |
| LeafNet | [Original paper](https://arxiv.org/html/2602.13662v1), [authors' benchmark code](https://github.com/EnalisUs/LeafBench), [requested AgML download](https://huggingface.co/datasets/Project-AgML/LeafNet) | HF displays **8.61 GB** | AgML release tagged CC BY 4.0; obtain original-source rights/provenance inventory. Paper license is not an image license | Public-source aggregation; exact overlaps unknown; matching familiar class totals are a warning, not proof of duplication |
| Agri-Foundation | [Uploader's card/download](https://huggingface.co/datasets/mbsoft31/agri-foundation-v1) | HF displays **3.82 GB** | Compilation/metadata CC BY-SA 4.0; card says image source licenses remain. PlantWild NC/ND and PlantSeg NC cannot be erased by a compilation tag | Explicitly incorporates PlantVillage, PlantDoc, New Plant Diseases, Tomato Leaf/Mendeley, Cassava, Wheat, PlantSeg and PlantWild |
| Arkansas | [University image library](https://www.uaex.uada.edu/yard-garden/resource-library/diseases/default.aspx), [search portal](https://plant-diseases.uada.edu/), [2022 inventory announcement](https://uaex.uada.edu/media-resources/news/2022/01-24-2022-Ark-plant-disease-database.aspx) | Unknown; no bulk archive verified | No open training/redistribution license verified; university asks users to contact Sherrie Smith for publication/presentation use | Extension photos can be indexed by web datasets; retain original credits/source IDs |

**Release discrepancies matter.** PlantVillage's headline and example split differ by one; use a pinned inventory. PlantDoc's current tree contains 2,342 train and 236 test files, including a two-file spider-mite folder absent from test; do not silently call this the paper's 27-class corpus. PlantWild v1 and v2 totals were independently verified from their official ZIP directories. PlantSeg's older [2024 preprint](https://arxiv.org/abs/2409.04038) describes 11,400 diseased plus 8,000 healthy images, whereas the published DOI inspected here supplies only 7,774 diseased images. No healthy subset should be inferred from that older description.

The Agri-Foundation uploader reports **51,323 MD5 duplicates removed**. MD5 can identify byte-identical files, but does not establish removal of resized/recompressed images, augmentations or repeated photographs of a leaf. The card's fuzzy alignment example involving “Tomato_Blight” is a reason to verify that early and late blight remain distinct. LeafNet's public 121,337 rows are about **65.2%**, not exactly 70%, of the paper's 186,000 headline; the public card's “~70%” language is approximate. Paper crop totals must not be claimed as public training counts.

PlantVillage's 14 crop labels are apple, blueberry, cherry, maize, grape, orange, peach, bell pepper, potato, raspberry, soybean, squash, strawberry and tomato. PlantDoc's 13 are the same list without orange. PlantWild v1 has 33 host/healthy categories; v2/PlantSeg include 34 hosts and numerous non-target crops. Full taxonomies are in the linked original manifests/papers; this report's class-level analysis is deliberately limited to AgriVision's six crops.

## Verified target-condition inventory

### PlantVillage: exact counts and proposed initial labels

Counts below were computed from **19 complete, non-truncated upstream RGB class trees**. All are original release files, not augmentation counts. A substantial source count establishes quantity, not unique plants or independently audited diagnoses. The file trees and their hashes are recorded locally in `artifacts/dataset_research_metadata.json`.

| Crop | Exact condition / proposed ID | Source files | Quantity-qualified pilot? |
|---|---|---:|---|
| Tomato | `tomato.healthy` | 1,591 | Yes |
| Tomato | `tomato.early_blight` | 1,000 | Yes |
| Tomato | `tomato.late_blight` | 1,909 | Yes |
| Tomato | `tomato.bacterial_spot` | 2,127 | Yes |
| Tomato | `tomato.leaf_mold` | 952 | Yes |
| Tomato | `tomato.septoria_leaf_spot` | 1,771 | Yes |
| Tomato | `tomato.target_spot` | 1,404 | Yes |
| Tomato | `tomato.mosaic_virus` | 373 | Yes; small margin |
| Tomato | `tomato.yellow_leaf_curl_virus` | 5,357 | Yes; downsample dominance |
| Tomato | `tomato.two_spotted_spider_mite_damage` | 1,676 | Yes; **pest**, not fungal disease |
| Potato | `potato.early_blight` | 1,000 | Yes |
| Potato | `potato.late_blight` | 1,000 | Yes |
| Potato | `potato.healthy` | 152 | **No** |
| Maize | `maize.gray_leaf_spot` | 513 | Yes |
| Maize | `maize.common_rust` | 1,192 | Yes |
| Maize | `maize.northern_leaf_blight` | 985 | Yes |
| Maize | `maize.healthy` | 1,162 | Yes |
| Bell pepper | `pepper_bell.bacterial_spot` | 997 | Yes |
| Bell pepper | `pepper_bell.healthy` | 1,478 | Yes |

Total: **26,639 files**, 19 combinations; **18** meet the quantity rule. Source maize folder name is `Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot`; retain the original label in provenance. These bell-pepper files do not establish performance on all chili/hot/sweet pepper varieties.

### Field/web supplements: exact available counts

PV = PlantVillage; PD = current PlantDoc train + test; PW1/PW2 = official PlantWild archives; PS = published PlantSeg CSV. **Never sum these columns into a unique-image total.** PD test files are not proposed training data. Dash means the relevant class was not found in the inspected release, not that the condition does not exist agriculturally. Broader source labels are kept separate.

| Crop-condition label | PD | PW1 | PW2 | PS |
|---|---:|---:|---:|---:|
| Tomato healthy / leaf | 63 | 226 | — | — |
| Tomato early blight | 88 | 346 | 187 | 153 |
| Tomato late blight | 111 | 295 | 163 | 117 |
| Tomato bacterial leaf spot | 110 | 280 | 110 | 90 |
| Tomato leaf mold | 91 | 239 | 156 | 102 |
| Tomato Septoria leaf spot | 151 | 220 | 130 | 99 |
| Tomato mosaic virus | 54 | 189 | 63 | 43 |
| Tomato yellow virus / yellow leaf curl | 76* | 171 | 93 | 63 |
| Tomato two-spotted spider mites | 2 | — | — | — |
| Potato early blight | 117 | 227 | 126 | 68 |
| Potato late blight | 105 | 240 | 117 | 78 |
| Potato healthy / leaf | — | 249 | — | — |
| Maize gray leaf spot | 68 | 216 | 107 | 76 |
| Maize leaf blight / northern leaf blight | 192* | 224 | 130 | 92 |
| Maize rust (generic source label) | 116 | 237 | 177 | 120 |
| Maize smut | — | 293 | 202 | 131 |
| Maize healthy / leaf | — | 156 | — | — |
| Bell pepper healthy / leaf | 61 | 240 | — | — |
| Bell pepper leaf spot (generic source label) | 71 | 117 | — | — |
| Bell pepper bacterial spot | — | — | 76 | 53 |
| Bell pepper frogeye leaf spot | — | — | 31 | 24 |
| Bell pepper powdery mildew | — | — | 28 | 18 |
| Bell pepper blossom end rot | — | — | 112 | 81 |
| Cabbage healthy / leaf | — | **464** | — | — |
| Cabbage Alternaria leaf spot | — | 128 | 63 | 39 |
| Cabbage black rot | — | — | 131 | 93 |
| Cabbage downy mildew | — | — | 84 | 49 |
| Collard greens, any condition | — | — | — | — |

\* PlantDoc's “Tomato leaf yellow virus” and “Corn leaf blight” require expert mapping; no automatic equivalence is approved. Likewise “leaf spot” does not prove bacterial spot, and generic “rust” does not prove common rather than southern rust. Blossom end rot concerns fruit and abiotic stress; exclude from a leaf-only disease model.

**Exactly which combinations meet the verified quantity screen?** The 18 “Yes” PlantVillage combinations above, plus **cabbage healthy (464 PW1 files)**: **19 distinct combinations**. PW1 tomato early blight also passes with 346, but it is already included among the 18 tomato/maize/potato/bell-pepper combinations. Cabbage healthy remains NC/ND-restricted and does not make cabbage disease classification ready. No collard combination qualifies. Potato healthy needs more independent healthy leaves. No additional disease combination is credited using an unverified public subset count or a sum of overlapping sources.

## Cabbage, collard, Brassica and pest-damage search

Searches covered Kaggle, Hugging Face, GitHub, Zenodo, Mendeley Data, Dryad, university repositories and academic papers. “Not verified” describes this search, not a claim that no dataset exists anywhere.

| Candidate and official/source link | Count, crop and class evidence | Images, annotations and size | License, overlap and assessment |
|---|---|---|---|
| [Image dataset of Cabbage Crop diseases, Mendeley v1](https://data.mendeley.com/datasets/sjmgzhwrxv/1) | Cabbage Alternaria leaf spot, black rot, downy mildew, healthy; **original per-class counts unknown** | Diverse environments reported; native resolution/diagnostic QA unknown; archive **140,504,136 bytes**; outer ZIP contains separate original and augmentation ZIPs | **CC BY 4.0**. Best direct cabbage disease acquisition candidate; inventory originals and group every augmentation with its parent |
| [Balanced Cabbage Disease Dataset, Kaggle](https://www.kaggle.com/datasets/mubbassir/balanced-cabbage-dataset-200-each) | Owner reports **8×200 = 1,600 files**, explicitly through augmentation/trimming; independent-original counts and complete class names not verified | Resolution/background/diagnostic reviewer unknown; API reports **1,782,143,369 bytes** | API says **CC0: Public Domain**, but original photographer/source rights unverified. Do not use the 200-file classes as independent count evidence; likely reuse must be audited |
| [Comprehensive Vegetable Leaf Disease Image Collection, Mendeley](https://data.mendeley.com/datasets/rh8c5tgg5k/1) | 1,923 processed images across broccoli, cabbage, cauliflower, turnip. **Cabbage: Alternaria 107, damaged leaf 87, grey mould 83, healthy 132, tip burn 90** | Folder classes; native resolution/background, original-vs-processed lineage and diagnostic expert review unknown; byte size not verified | **CC BY 4.0**. All cabbage classes below screen. “Damaged” does not identify a pest; tip burn is abiotic. Other crop counts cannot fill cabbage/collard gaps |
| [YEESI Lab, Zenodo](https://zenodo.org/records/7893938) | Paper/record 7,992 across 14 named crops including cabbage, Chinese cabbage, leaf kale, maize, peppers and tomato; selected record exposes cabbage healthy and CP deficiency, maize FAW/aphid/streak-virus folders | Smartphone/GoPro field photos, Morogoro Tanzania; per-class counts/resolutions and diagnostic validation not established here; selected files **19.3 GB** displayed | **CC BY 4.0** verified in API. Regionally relevant candidate; record description and actual file list differ, so do not infer all listed crops/classes are downloadable. CP deficiency is not infectious disease; leaf kale is not collard |
| [Cauliflower Leaf Diseases, Mendeley](https://data.mendeley.com/datasets/x995snz7p3/1), [AgML mirror](https://huggingface.co/datasets/Project-AgML/cauliflower_leaf_disease_classification) | **2,661**: black rot 1,088; healthy 934; insect hole 639; **cauliflower only** | Variable capture conditions; [original paper](https://pubmed.ncbi.nlm.nih.gov/40534720/) reports 3,000×3,000 preprocessing; classification; expert diagnostic verification not established; AgML displays **5.26 GB** | **CC BY 4.0**. Useful related-crop research, **not cabbage or collard training evidence**. Same-source mirror is not new data |
| [Roboflow cabbage-pest project](https://universe.roboflow.com/ksb-yolo-lable/cabbage-pest) | **503 images** displayed; two near-identical generic “cabbage pest” labels; no species/healthy breakdown | Detection boxes; resolution/byte size/capture details and expert QA unknown | **CC BY 4.0** displayed. Pest presence is not labelled leaf damage. Require crop/species verification and box inspection before use |
| [Cabbage Pest Identification Dataset, Mobiusi](https://www.mobiusi.com/datasets/dfb6c6977a41559b7832eb425dff7934) | Vendor claims **20,000 records**, not verified distinct images; species/condition counts absent | Vendor describes JPG/PNG/JSON, multiple capture environments; claims **3.8G**; resolution and annotation audit unknown | Full access by contact; “CATL” shown, no reviewed open license. Do not count toward available training images or spend/download yet |
| [Arko007 cabbage disease v2, HF](https://huggingface.co/datasets/Arko007/cabbage-disease-detection-v2) | Public dataset listing exists; image count/condition distribution not exposed in parsed page | Classification/detection tags; resolution, bytes and annotation QA unknown | **CC BY 4.0 tag**; original-source provenance not verified. [Associated CabbageGuard model card](https://huggingface.co/Arko007/cabbageguard-efficientnetv2-8class) describes a **private** merged set derived from Mendeley and Kaggle PEST_AI; do not assume it is the same public release or independent data |
| [NZDLPlantDisease-v2 study](https://pmc.ncbi.nlm.nih.gov/articles/PMC9641257/) | Paper reports cabbage ring spot **192**; broccoli/cauliflower classes also appear | Exact available archive, original-image inventory, resolution and size not verified | Dataset license/access not established; article access license does not prove image redistribution rights. Leads only; ring spot below screen |
| [Leafy vegetable few-shot study](https://www.mdpi.com/2223-7747/14/5/760) | Paper describes cabbage and Chinese cabbage disease imagery; no accessible licensed training archive verified | Detection/segmentation research; available original counts/resolution/size/QA remain unverified | Do not count paper training totals as available public originals. Request source manifest and data terms before inclusion |
| [Hawassa/Sidama cabbage thesis](https://etd.hu.edu.et/server/api/core/bitstreams/65b0842c-0ec6-4526-8908-ddc502c114d9/content) | Reports **5,700 images**, five diseases plus healthy; downloadable image dataset and original/augmentation breakdown not verified | Thesis access only; image resolutions, bytes, diagnostic QA unknown | Image license unknown. Promising African collection lead, not verified available training data |
| [Collard bacterial leaf blight, USDA/Dryad](https://datadryad.org/dataset/doi%3A10.5061/dryad.4851qq0) | **True collard/collard-like accessions**, Pseudomonas cannabina pv. alisalensis screening | Published files are CSV/TXT resistance statistics, **34.27 KB**, not a labelled RGB image corpus | No image training entitlement/count can be inferred; useful evidence for selecting collard collection targets |
| [Brassica cultivar phenotypes, Zenodo](https://zenodo.org/records/18374537) | 284 seedling and 141 mature cultivars; these are **cultivar counts**, not image counts; no disease class inventory | RGB/LLM-assisted phenotype annotations; **4.1 GB** displayed; resolution unknown | **CC BY 4.0** stated. Morphology collection, not collard/cabbage disease ground truth |
| [Oilseed rape foliar dataset, INRAE](https://entrepot.recherche.data.gouv.fr/dataset.xhtml?persistentId=doi%3A10.57745%2FR3HZOQ) | Brassica **napus**; disease class names listed, image counts unknown | Field RGB and some symptom segmentation; **11.3 GB** displayed; embargoed listing; resolution unknown | Custom **CC-BY-NC** terms; not cabbage or collard. Do not treat as available target training data |
| [CIRAD cabbage pest-control dataset](https://dataverse.cirad.fr/dataset.xhtml?persistentId=doi%3A10.18167%2FDVN1%2FAWCNQD) | 454 tabular observations of pest-control literature | XLS/TAB plus documentation; original-format ZIP **211.7 KB**; no image corpus | **CC BY 4.0**; relevant agronomy, unsuitable for RGB training |
| [Cabbage UAV growth dataset study](https://pmc.ncbi.nlm.nih.gov/articles/PMC11263960/) | Cabbage growth/instance segmentation, not disease-labelled crop-condition evidence | Aerial plant outlines; disease/healthy/pest class counts not established | Original record/rights and byte/resolution inventory would need checking; exclude from disease count ledger |

Additional searches returned food-ingredient or produce-identification photos labelled collard, sequencing accessions, disease reference pages and general insect-species datasets. These are **not verified healthy collard leaves or collard pest-damage ground truth**. The [GitHub Cropper project](https://github.com/Mingyang-Guo/Cropper) explicitly distinguishes cabbage nutrient-deficiency classification from Chinese cabbage botanical leaf spot; these cannot be silently relabelled infectious cabbage or collard diseases.

### Crop identity and pathology boundaries

Use explicit host metadata: tomato (*Solanum lycopersicum*), potato (*S. tuberosum*), maize (*Zea mays*), verified bell pepper (*Capsicum annuum*, bell cultivar group), head cabbage (*Brassica oleracea*, Capitata group), and **verified collard** (*B. oleracea*, collard/viridis cultivar identity). Keep cultivar/common-name evidence even where taxonomic nomenclature differs between sources.

Chinese cabbage (*B. rapa*), cauliflower, broccoli, kale, turnip and oilseed rape are separate hosts/crop groups. A shared pathogen is not shared training distribution. The USDA collard study verifies collard blight relevance; [Illinois Extension](https://ipm.illinois.edu/diseases/series900/rpd924/) also documents collard susceptibility to black rot. Neither provides enough independent collard training photographs.

Holes, tears and discoloration alone must not be labelled diamondback moth, cabbage looper, aphid injury or a specific pathogen without supporting diagnostic evidence. Do not merge bacterial leaf blight with black rot, Alternaria with generic leaf spot, healthy across crops, or nutrient deficiency with infectious disease. A visible insect and the injury it causes are different annotation targets.

## Proposed AgriVision class taxonomy

Store `class_id`, `crop_id`, `crop_species`, `cultivar_group`, `condition_type`, `condition_id`, source label, diagnostic certainty and annotation version. Use one crop-condition output per explicit class; reserve model output indices for an independently versioned future mapping. **Keep the existing five-class checkpoint/mapping intact.**

| Tier | Proposed outputs | Readiness / reason |
|---|---|---|
| A: retain tomato scope | `tomato.healthy`, `.early_blight`, `.late_blight`, `.bacterial_spot`, `.leaf_mold` | Existing working classes; qualify in source quantity; still need independent field evaluation |
| B: first new-crop experiment | `maize.healthy`, `.gray_leaf_spot`, `.common_rust`, `.northern_leaf_blight`; `pepper_bell.healthy`, `.bacterial_spot`; `potato.healthy`, `.early_blight`, `.late_blight` | **14 outputs including Tier A**; potato healthy is a collection gate; pepper scope remains bell |
| C: optional tomato expansion | `tomato.septoria_leaf_spot`, `.target_spot`, `.mosaic_virus`, `.yellow_leaf_curl_virus`, `.two_spotted_spider_mite_damage` | Quantity-qualified, but add only after field validation and confounder review; type last label as pest damage |
| D: cabbage collection targets | `cabbage.healthy`, `.alternaria_leaf_spot`, `.black_rot`, `.downy_mildew`; later `.chewing_damage_unspecified` | Original disease counts unresolved/low; healthy PW1 qualifies only numerically and has restrictive terms; unspecified chewing needs newly labelled data |
| E: collard collection targets | `collard.healthy`, `.black_rot`, `.alternaria_leaf_spot`, `.downy_mildew`, `.bacterial_leaf_blight_pca`, `.chewing_damage_unspecified` | **All disabled pending verified collard images** and local expert priority review; proposed classes are not claims of existing dataset coverage |

Treat **unsupported crop, uncertain condition, poor photo and mixed symptoms** as application outcomes/rejection states. A confident closed-set softmax prediction does not prove the input belongs to a supported class. Do not create an “unknown” training class without representative negative data. Pathogen species and pest species should remain supporting metadata unless diagnosis is sufficiently verified to justify that output granularity.

## Recommended combination and staged plan

### Preferred product path

1. **Core:** original PlantVillage RGB for Tier A/B and later selected Tier C. Use physical-leaf groups and downsample dominant classes; resolve the upstream licensing assumption. All 19 target classes occupy about **422.45 MB of raw image payload**, so acquiring irrelevant crops or all visual variants is unnecessary.
2. **Field diversity:** separately acquire and audit the original PlantDoc target folders, retaining its test partition for evaluation. Its “leaf spot”, “yellow virus” and “rust” labels are not automatic canonical labels. Small per-class counts make it a supplement, not a complete field-generalization solution.
3. **Regional supplement:** inspect selected YEESI metadata and originals for compatible maize/pepper/healthy cabbage classes. It is geographically more relevant than controlled US leaf photographs, but crop-condition and diagnostic checks remain required. Neither CP deficiency nor tomato leaf-miner mentions create a verified disease class here.
4. **Cabbage:** prioritize original-only Mendeley cabbage disease images, then fill the healthy/disease deficits with fresh local photographs. Do not import bundled augmentations as independent examples. The comprehensive vegetable set is a small supplementary source after lineage review.
5. **Collard:** collect a dedicated, agronomist-reviewed dataset. Do not ship collard diagnosis using cabbage, cauliflower or kale labels. Keep collard outputs disabled until the same validation gates pass.

This is a **conditional source recommendation**, not approval to download or a claim of a fully licensed production corpus. If a source's rights cannot be verified, replace it with consented local images.

### Optional noncommercial research branch

Use selected **PlantWild v1** classes for healthy examples and field variation, with v2/PlantSeg as alternatives or annotation supplements after cross-version deduplication. Prefer one provenance family at a time. PlantSeg masks can help evaluate lesion-aware training crops and full-frame sensitivity; its small target-class counts do not independently resolve the cabbage gap. PlantWild's NC/ND and PlantSeg's NC restrictions make them unsuitable as an assumed unrestricted product default.

**Do not use Agri-Foundation plus its source datasets as if they were independent data.** It may save label-organizing work, but introduces inherited restrictions, normalization risk and near-duplicate leakage. LeafNet can be investigated later for targeted image-only pretraining; downloading 121k captioned samples and training a VLM does not fit the current lightweight classifier objective.

### Collection and validation targets (proposals, not available counts)

For each enabled crop-condition, target **500–1,000 distinct field photographs** across multiple farms, days, cultivars, lighting conditions and Android cameras, with at least **100 independent field test examples** as a practical initial evaluation goal. Include early/mild and severe symptoms, both leaf sides where relevant, healthy senescent leaves, abiotic stress and confusing diseases. Record plant/session/farm IDs and expert diagnostic confidence; confirm a subset with laboratory diagnosis where visually ambiguous.

Before training, produce an ingestion ledger with source/version, original URL/file ID, rights evidence, original-vs-augmentation lineage, crop/cultivar, condition, tissue, resolution, byte hash, decoded-pixel hash, perceptual-duplicate group and capture group. Quarantine label disagreements. Group duplicate leaves, burst photos, masks, detection crops and generated variants **before** splitting. Check cross-source duplicates with decoded-pixel hashing plus perceptual similarity/manual review, not MD5 alone. Retain published benchmark partitions and add a separate local-farm test set; do not tune against that test set.

Report per-class precision/recall/F1, confusion matrices, field-vs-controlled performance and uncertainty/rejection rates. Examine potato healthy and early blight confusions, generic maize rust, mixed pathology and damaged Brassica leaves. No held-out disease image should be relabelled merely to agree with the model.

## MobileNetV3-Small and offline Android implications

All confirmed RGB classification collections are architecturally compatible after appropriate label extraction and preprocessing. Detection datasets need reviewed leaf/lesion crops and must preserve source-image grouping. Segmentation masks are optional training metadata, not a requirement to replace the existing classifier. A 224×224 input keeps training and inference inexpensive but can erase small early lesions and pest evidence; test crop framing and full-image sensitivity instead of claiming resolution resizing preserves all diagnostic information.

Use the existing backbone with a future versioned output head. For a TorchVision-style 1,024-feature final layer, each extra output adds **1,025 parameters**: about 4,100 float32 bytes or 1,025 int8 parameter bytes, excluding metadata/alignment. **Dataset image count increases training cost, not deployed backbone size.** A 14-class model does not require a 14-model ensemble. Exact latency, RAM, APK and exported-model size cannot be established without conversion and device benchmarks.

For a later experiment, start with an ImageNet-initialized frozen backbone and a balanced head-training stage, then a short selective fine-tuning stage with early stopping. Cap samples per class/source and cache 224-pixel training inputs; choose epoch budgets from learning curves. No training-hour estimate is justified without hardware and a final audited inventory.

Recommended future export path: **PyTorch → LiteRT Torch → `.tflite` → native Android LiteRT**, invoked from Flutter. Google's [converter](https://github.com/google-ai-edge/litert-torch) supports on-device deployment and currently documents a Linux conversion environment; conversion can run in Colab while Android inference requires **neither Python nor internet**. Export compatibility of this exact model, including hard-swish and squeeze/excitation, still needs a proof test; do not assume a PyTorch `.pt` file runs directly in Flutter.

Bundle the converted model, exact class mapping, preprocessing version and reviewed disease guidance inside the application. Compare float32 and int8 outputs on a fixed golden set covering every crop and class. [Integer quantization](https://developers.google.cn/edge/litert/conversion/tensorflow/quantization/model_optimization) needs representative calibration inputs and can reduce weight storage substantially; preserve disease recall and test CPU fallback on representative low-cost phones. The runtime/library overhead and delegate compatibility also affect APK size. Verify complete photo-to-result operation in airplane mode with the backend unavailable, including first launch; no cloud captioning, model download or remote guidance lookup should be required.

## Rights and unresolved gates

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) permits adaptation and redistribution with attribution and change notices. [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) adds ShareAlike requirements for adapted licensed material. [CC BY-NC](https://creativecommons.org/licenses/by-nc/4.0/) restricts commercial use; [CC BY-NC-ND](https://creativecommons.org/licenses/by-nc-nd/4.0/) also restricts distribution of adapted licensed material. These data terms must not be replaced by a software repository's MIT/Apache license, a notebook license or an aggregator's tag. Whether particular trained weights constitute adapted material is not established by a dataset card; obtain written terms covering the intended training, model distribution and image redistribution where ambiguity matters. No permission requests were sent.

Open items before any acquisition/training phase:

- Pin source revisions; verify PlantVillage's original data license and PlantDoc web-photo provenance.
- Inventory Mendeley cabbage **originals only**, obtaining per-condition counts and diagnostic QA; do not use augmentation totals.
- Establish per-class counts/rights in LeafNet's **public** subset and Agri-Foundation's source ledger before considering them.
- Reconcile YEESI's description with its downloadable inventory and distinguish bell/hot peppers and cabbage/Chinese cabbage/leaf kale.
- Obtain sufficient independent potato healthy images; establish local field coverage for each enabled class.
- Build dedicated collard healthy/disease/pest-damage collections with verified host identity.
- Prove export/runtime parity and Android performance in a subsequent authorized implementation phase.

## Reproducibility notes

Public metadata inspected without cloning repositories or downloading full archives:

- PlantVillage RGB parent tree SHA: `6985a76f66926faf50eeae1299ccc50bc01a0a4a`. Full parent recursive calls were truncated and **discarded for counting**; individual class subtrees were complete. [Tree API](https://api.github.com/repos/spMohanty/PlantVillage-Dataset/git/trees/6985a76f66926faf50eeae1299ccc50bc01a0a4a).
- PlantDoc count from its complete [classification tree API](https://api.github.com/repos/pratikkayal/PlantDoc-Dataset/git/trees/master?recursive=1), selecting image files beneath `train/` and `test/`.
- Official PlantWild v1/v2 ZIP central directories; no image decoding. Metadata evidence stored in `artifacts/dataset_research_plantwild_v1.json` and `artifacts/dataset_research_archive_metadata.json`.
- PlantSeg [record API](https://zenodo.org/api/records/17719108) and `Metadata.csv` only, read using bounded HTTP Range requests. Image split counts are **5,367 train / 846 validation / 1,561 test**; these are the actual release counts, not exact arithmetic 70/10/20. CSV retained in `artifacts/dataset_research_plantseg_metadata.csv`.
- Mendeley cabbage [file-list API](https://data.mendeley.com/public-api/datasets/sjmgzhwrxv/files?folder_id=root&version=1); nested ZIP names establish original/augmentation separation but not per-class image counts.
- Kaggle [dataset metadata API](https://www.kaggle.com/api/v1/datasets/view/mubbassir/balanced-cabbage-dataset-200-each) establishes CC0 tag, bytes and the uploader's augmentation statement; public web parsing did not expose class names.

All source links were inspected during this research or are original download/code links reached through the inspected publisher pages. Inaccessible detail is explicitly marked unknown. No models were overwritten, no retraining or Flutter changes were performed, and nothing was pushed to GitHub.

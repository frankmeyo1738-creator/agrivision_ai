"""Bundle only the evaluated, parity-verified Phase 4 model with local care text."""
import json
import shutil
from pathlib import Path

from backend.app.services.diseases import DISEASES
from training.multicrop.convert import validate_run
from training.multicrop.pipeline import CONFIG, LABELS, PREPROCESSING, sha256, write_json


def bundle():
    run = Path("artifacts/phase4_colab_return/phase4_run")
    export = Path("artifacts/phase4_android_export")
    validate_run(run)
    report = json.loads((export / "conversion_verification.json").read_text())
    model = export / "multicrop_mobilenet_v3_small.onnx"
    if not report["passed"] or len(report["cases"]) != 14 or report["model_sha256"] != sha256(model) \
            or report["checkpoint_sha256"] != sha256(run / "best_model.pt") or report["class_order"] != LABELS:
        raise ValueError("Passing conversion for this checkpoint is required")
    guidance = dict(DISEASES)
    corn_root = "https://extension.umn.edu/agriculture/crop-production/corn/"
    vegetable_root = "https://extension.umn.edu/disease-management/"
    cases = {
        "Maize Common Rust": (
            "Rust-coloured pustules on maize leaves may indicate common rust, a fungal disease. Similar rusts can look alike.",
            ["Inspect both leaf surfaces and monitor disease spread.", "Use resistant maize hybrids; ask a local agronomist whether treatment is warranted."],
            ["Plan resistant hybrids for future planting.", "Base any fungicide decision on confirmed disease, crop stage and local risk."],
            corn_root + "common-rust-on-corn"),
        "Maize Gray Leaf Spot": (
            "Gray leaf spot can produce rectangular grey or brown lesions limited by maize leaf veins. Humid conditions favour disease.",
            ["Scout lower and upper leaves and seek confirmation of rectangular lesions.", "Use crop rotation and locally appropriate residue management."],
            ["Choose resistant hybrids.", "Assess fungicide need with a local agronomist; an image score alone is insufficient."],
            corn_root + "gray-leaf-spot-on-corn"),
        "Maize Northern Leaf Blight": (
            "Northern leaf blight can cause elongated, canoe-shaped lesions that become tan on maize leaves.",
            ["Inspect lesion shape and disease progression, especially before silking.", "Seek local advice when symptoms spread rapidly."],
            ["Use resistant maize hybrids and rotate crops.", "Manage infected residue where appropriate for local soil-conservation practices."],
            corn_root + "northern-corn-leaf-blight"),
        "Potato Early Blight": (
            "Early blight may produce brown spots with concentric rings on potato leaves and lead to loss of foliage.",
            ["Scout affected foliage and confirm the cause before treatment.", "Reduce prolonged leaf wetness and maintain balanced crop nutrition."],
            ["Rotate away from susceptible crops and manage infected residue.", "Use healthy planting material and suitable spacing."],
            vegetable_root + "early-blight-tomato-and-potato"),
        "Potato Late Blight": (
            "Late blight may cause rapidly enlarging water-soaked or dark lesions on potato foliage and can also affect tubers.",
            ["Seek prompt local agricultural advice if late blight is suspected; it can spread quickly.", "Avoid moving suspect infected plant material to other fields."],
            ["Plant certified healthy seed potatoes and eliminate volunteer plants and infected cull sources.", "Monitor local disease warnings and follow locally approved management guidance."],
            vegetable_root + "late-blight"),
        "Bell Pepper Bacterial Spot": (
            "Bacterial spot can cause water-soaked or brown spots on pepper foliage and may also damage fruit.",
            ["Avoid handling plants when leaves are wet and reduce overhead irrigation.", "Seek confirmation before treatment; similar leaf spots have different causes."],
            ["Use disease-free seed or transplants and rotate susceptible crops.", "Clean tools and manage infected crop residue."],
            vegetable_root + "bacterial-spot-tomato-and-pepper"),
    }
    for label, (description, management, prevention, source) in cases.items():
        guidance[label] = dict(description=description, management=management, prevention=prevention, sources=[source])
    for crop in ("Maize", "Potato", "Bell Pepper"):
        guidance[crop + " Healthy"] = {
            "description": f"Leaf patterns most closely match the model's healthy {crop.lower()} examples. This does not exclude pests, nutrient stress or unsupported diseases.",
            "management": ["Continue regular scouting and locally appropriate crop care.", "Seek agricultural advice if symptoms persist despite a healthy model match."],
            "prevention": ["Use healthy planting material and clean tools.", "Monitor the whole plant rather than relying on one leaf photo."],
            "sources": [corn_root + "corn-pest-management" if crop == "Maize" else
                        "https://extension.umn.edu/garden-and-home/yard-and-garden/gardening-in-minnesota/growing-potatoes" if crop == "Potato" else vegetable_root + "bacterial-spot-tomato-and-pepper"],
        }
    guidance["Maize Healthy"]["sources"] = ["https://extension.umn.edu/corn/corn-pest-management"]
    if set(guidance) != set(LABELS):
        raise ValueError("All fourteen guidance entries are required")
    manifest = {
        "format_version": 1, "architecture": "mobilenet_v3_small", "model_file": model.name,
        "runtime": "onnxruntime-android", "runtime_version": "1.23.2",
        "model_sha256": sha256(model), "checkpoint_sha256": sha256(run / "best_model.pt"),
        "labels": LABELS, "classes": CONFIG["classes"], "preprocessing": PREPROCESSING,
        "guidance": guidance, "crop_scope": "Tomato, Maize, Potato and Bell Pepper leaves only",
        "confidence_note": "Confidence is the global softmax score among fourteen crop-condition classes, not diagnostic certainty. Crop selection does not verify plant identity. Field performance is not established; confirm important symptoms locally.",
        "evaluation": json.loads((run / "evaluation.json").read_text()),
    }
    write_json(export / "model_manifest.json", manifest)
    assets = Path("frontend/assets/models")
    shutil.copy2(model, assets / model.name)
    shutil.copy2(export / "model_manifest.json", assets / "model_manifest.json")
    print("Bundled evaluated fourteen-class ONNX and local guidance; native validation still required.")


if __name__ == "__main__":
    bundle()

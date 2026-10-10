"""Educational cultural-management guidance; citations travel with each response."""

BASE = "https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/"
CONFIDENCE_NOTE = (
    "Confidence is a softmax score among five classes, not diagnostic certainty. "
    "This model cannot verify that an image is a tomato leaf or detect every disease. "
    "Confirm significant symptoms with a local agricultural extension professional."
)
DISEASES = {
    "Tomato Healthy": {
        "description": (
            "The image most closely resembles the healthy training class. This does not "
            "exclude hidden disease, nutrient stress, or a condition outside the five classes."
        ),
        "management": [
            "Continue inspecting leaves, stems, and fruit for changes.",
            "Maintain consistent watering at the soil surface.",
        ],
        "prevention": [
            "Use healthy seed and transplants.",
            "Space and support plants to improve airflow.",
            "Remove crop residue and keep gardening tools clean.",
        ],
        "sources": [
            "https://extension.umn.edu/garden-and-home/yard-and-garden/"
            "gardening-in-minnesota/growing-tomatoes"
        ],
    },
    "Tomato Early Blight": {
        "description": (
            "Early blight produces dark brown leaf lesions, often with concentric rings "
            "and yellowing, and can affect stems and fruit."
        ),
        "management": [
            "Remove affected leaves carefully and clean tools afterward.",
            "Keep foliage dry and water at the base.",
            "Monitor remaining leaves for spreading symptoms.",
        ],
        "prevention": [
            "Mulch beneath plants to reduce soil splash.",
            "Stake plants and maintain airflow.",
            "Rotate crops and consider locally suitable resistant varieties.",
        ],
        "sources": [BASE + "early-blight-in-tomato-and-potato"],
    },
    "Tomato Late Blight": {
        "description": (
            "Late blight, caused by Phytophthora infestans, can spread quickly and cause "
            "water-soaked brown lesions on leaves, stems, and fruit."
        ),
        "management": [
            "Seek prompt local confirmation if lesions spread rapidly.",
            "Remove diseased foliage and manage affected crop residue.",
            "Reduce leaf wetness using soil-level irrigation.",
        ],
        "prevention": [
            "Inspect plants regularly, especially during wet weather.",
            "Space and support plants for air movement.",
            "Use healthy transplants and suitable resistant varieties.",
        ],
        "sources": [BASE + "late-blight"],
    },
    "Tomato Bacterial Spot": {
        "description": (
            "Bacterial spot causes small brown leaf spots, sometimes with yellow halos "
            "or holes, and can also damage fruit. Splashing water and handling spread it."
        ),
        "management": [
            "Remove visibly affected leaves and sanitize tools.",
            "Keep leaves dry with drip or base watering.",
            "Inspect nearby plants and obtain confirmation for severe symptoms.",
        ],
        "prevention": [
            "Buy seed and transplants from reputable sources.",
            "Do not save seed from affected plants.",
            "Rotate crops, remove residue, and maintain plant spacing.",
        ],
        "sources": [BASE + "bacterial-spot-of-tomato-and-pepper"],
    },
    "Tomato Leaf Mold": {
        "description": (
            "Leaf mold is a fungal disease favored by high humidity, especially under cover. "
            "Yellow patches above may correspond to olive-brown mold below the leaf."
        ),
        "management": [
            "Improve ventilation in greenhouses or covered growing areas.",
            "Water at the base and reduce humidity around foliage.",
            "Remove affected crop residue and clean supports and tools.",
        ],
        "prevention": [
            "Space, stake, and prune plants to improve air circulation.",
            "Use clean seed and transplants.",
            "Consider resistant varieties after checking local suitability.",
        ],
        "sources": [BASE + "tomato-leaf-mold"],
    },
}

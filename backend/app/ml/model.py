"""One architecture and preprocessing contract for training, testing, and serving."""

from torch import nn
from torchvision import transforms
from torchvision.models import MobileNet_V3_Small_Weights, mobilenet_v3_small

from .classes import CLASS_NAMES

PREPROCESSING = {
    "version": 1,
    "image_size": 224,
    "resize_short_edge": 256,
    "crop": "center",
    "interpolation": "bilinear",
    "mean": [0.485, 0.456, 0.406],
    "std": [0.229, 0.224, 0.225],
    "color_mode": "RGB",
    "exif_transpose": True,
}


def build_model(*, pretrained: bool = False, freeze_features: bool = False) -> nn.Module:
    weights = MobileNet_V3_Small_Weights.IMAGENET1K_V1 if pretrained else None
    model = mobilenet_v3_small(weights=weights)
    model.classifier[-1] = nn.Linear(model.classifier[-1].in_features, len(CLASS_NAMES))
    if freeze_features:
        for parameter in model.features.parameters():
            parameter.requires_grad = False
    return model


def inference_transform() -> transforms.Compose:
    return transforms.Compose(
        [
            transforms.Resize(256, interpolation=transforms.InterpolationMode.BILINEAR),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize(PREPROCESSING["mean"], PREPROCESSING["std"]),
        ]
    )


def training_transform() -> transforms.Compose:
    return transforms.Compose(
        [
            transforms.Resize(256, interpolation=transforms.InterpolationMode.BILINEAR),
            transforms.RandomResizedCrop(224, scale=(0.8, 1.0)),
            transforms.RandomHorizontalFlip(),
            transforms.RandomRotation(15),
            transforms.ColorJitter(brightness=0.15, contrast=0.15, saturation=0.1),
            transforms.ToTensor(),
            transforms.Normalize(PREPROCESSING["mean"], PREPROCESSING["std"]),
        ]
    )

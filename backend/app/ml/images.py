"""Bounded image decoding shared by the CLI and HTTP service."""

import io
import warnings

from PIL import Image, ImageOps, UnidentifiedImageError

MAX_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000
ALLOWED_FORMATS = {"JPEG", "PNG", "WEBP"}


class InvalidImageError(ValueError):
    pass


class ImageTooLargeError(InvalidImageError):
    pass


class UnsupportedImageError(InvalidImageError):
    pass


def decode_image(data: bytes) -> Image.Image:
    if len(data) > MAX_UPLOAD_BYTES:
        raise ImageTooLargeError("Image exceeds the 10 MiB upload limit.")
    if not data:
        raise InvalidImageError("Image file is empty.")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.format not in ALLOWED_FORMATS:
                    raise UnsupportedImageError("Use a JPEG, PNG, or WebP image.")
                if image.width * image.height > MAX_IMAGE_PIXELS:
                    raise ImageTooLargeError("Image exceeds the 20 megapixel limit.")
                image.load()
                return ImageOps.exif_transpose(image).convert("RGB")
    except (Image.DecompressionBombWarning, Image.DecompressionBombError) as exc:
        raise ImageTooLargeError("Image dimensions are too large.") from exc
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError) as exc:
        if isinstance(exc, InvalidImageError):
            raise
        raise InvalidImageError("Image is corrupt or cannot be decoded.") from exc

import logging

from fastapi import APIRouter, File, HTTPException, Request, UploadFile
from starlette.concurrency import run_in_threadpool

from backend.app.api.schemas import HealthResponse, PredictionResponse
from backend.app.ml.images import (
    MAX_UPLOAD_BYTES,
    ImageTooLargeError,
    InvalidImageError,
    UnsupportedImageError,
)
from backend.app.ml.inference import ModelUnavailableError
from backend.app.services.diseases import CONFIDENCE_NOTE, DISEASES

router = APIRouter()
logger = logging.getLogger(__name__)
CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


@router.get("/health", response_model=HealthResponse)
def health(request: Request):
    return {
        "status": "ok",
        "model_loaded": request.app.state.engine.loaded,
        "model_message": request.app.state.model_message,
    }


@router.post("/predict", response_model=PredictionResponse)
async def predict(request: Request, image: UploadFile = File(...)):
    try:
        if image.content_type not in CONTENT_TYPES:
            raise HTTPException(415, "Use a JPEG, PNG, or WebP image.")
        # Read only one byte beyond the limit; never read an unbounded upload into RAM.
        data = await image.read(MAX_UPLOAD_BYTES + 1)
        if len(data) > MAX_UPLOAD_BYTES:
            raise HTTPException(413, "Image exceeds the 10 MiB upload limit.")
        result = await run_in_threadpool(request.app.state.engine.predict_bytes, data)
        result["disease_information"] = DISEASES[result["predicted_class"]]
        result["confidence_note"] = CONFIDENCE_NOTE
        return result
    except ImageTooLargeError as exc:
        raise HTTPException(413, str(exc)) from exc
    except UnsupportedImageError as exc:
        raise HTTPException(415, str(exc)) from exc
    except InvalidImageError as exc:
        raise HTTPException(400, str(exc)) from exc
    except ModelUnavailableError as exc:
        raise HTTPException(503, request.app.state.model_message or str(exc)) from exc
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Prediction failed")
        raise HTTPException(
            500, "Analysis failed. Please retry or check the backend logs."
        ) from exc
    finally:
        await image.close()

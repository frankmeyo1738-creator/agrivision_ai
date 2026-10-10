"""Run: python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000"""

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

import torch
from fastapi import FastAPI

from backend.app.api.routes import router
from backend.app.ml.inference import InferenceEngine, ModelUnavailableError

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


def create_app(model_dir: Path | None = None) -> FastAPI:
    directory = model_dir or Path(os.getenv("AGRIVISION_MODEL_DIR", REPOSITORY_ROOT / "models"))

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        torch.set_num_threads(4)
        application.state.engine = InferenceEngine(directory)
        application.state.model_message = None
        try:
            application.state.engine.load()
        except ModelUnavailableError as exc:
            application.state.model_message = str(exc)
            logging.getLogger(__name__).warning("%s", exc)
        yield

    application = FastAPI(title="AgriVision AI", version="0.1.0", lifespan=lifespan)
    application.include_router(router)
    return application


app = create_app()

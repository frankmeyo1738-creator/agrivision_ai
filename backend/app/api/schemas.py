from pydantic import BaseModel, Field


class HealthResponse(BaseModel):
    status: str = "ok"
    model_loaded: bool
    model_message: str | None = None


class TopPrediction(BaseModel):
    class_name: str = Field(alias="class")
    confidence: float = Field(ge=0, le=1)


class DiseaseInformation(BaseModel):
    description: str
    management: list[str]
    prevention: list[str]
    sources: list[str]


class PredictionResponse(BaseModel):
    predicted_class: str
    confidence: float = Field(ge=0, le=1)
    top_predictions: list[TopPrediction] = Field(min_length=3, max_length=3)
    disease_information: DiseaseInformation
    confidence_note: str

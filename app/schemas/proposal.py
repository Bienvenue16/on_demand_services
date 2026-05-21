from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.schemas.common import PyObjectId


class ProposalCreate(BaseModel):
    request_id: str
    message: str
    price_estimate: Optional[float] = None


class ProposalOut(BaseModel):
    id: PyObjectId
    request_id: PyObjectId
    provider_id: PyObjectId
    message: str
    price_estimate: Optional[float]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ProposalStatusUpdate(BaseModel):
    status: str

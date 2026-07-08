from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class ProposalCreate(BaseModel):
    request_id: str
    message: str
    price_estimate: Optional[float] = None


class ProposalOut(BaseModel):
    id: str
    request_id: str
    provider_id: str
    message: str
    price_estimate: Optional[float]
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ProposalStatusUpdate(BaseModel):
    status: str

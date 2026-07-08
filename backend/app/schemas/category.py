from pydantic import BaseModel
from typing import Optional


class CategoryCreate(BaseModel):
    name: str
    slug: str
    icon: str = ""


class CategoryOut(BaseModel):
    id: str
    name: str
    slug: str
    icon: str
    is_active: bool

    model_config = {"from_attributes": True}


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    slug: Optional[str] = None
    icon: Optional[str] = None
    is_active: Optional[bool] = None

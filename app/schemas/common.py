from pydantic import BaseModel, BeforeValidator
from typing import Generic, TypeVar, List, Annotated

# Convertit automatiquement un ObjectId MongoDB en str lors de la validation Pydantic
PyObjectId = Annotated[str, BeforeValidator(str)]

T = TypeVar("T")


class PaginatedResponse(BaseModel, Generic[T]):
    total: int
    page: int
    limit: int
    data: List[T]


class MessageResponse(BaseModel):
    message: str


class ErrorResponse(BaseModel):
    detail: str

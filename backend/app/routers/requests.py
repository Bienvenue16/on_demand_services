from fastapi import APIRouter, Depends
from typing import Optional
from app.schemas.service_request import ServiceRequestCreate, ServiceRequestUpdate, StatusUpdate
from app.services import request_service
from app.core.security import get_current_user

router = APIRouter()


@router.post("", status_code=201)
async def create_request(body: ServiceRequestCreate, current_user=Depends(get_current_user)):
    return await request_service.create(body, current_user)


@router.get("")
async def list_requests(
    page: int = 1,
    limit: int = 20,
    category_id: Optional[str] = None,
    status: Optional[str] = None,
    current_user=Depends(get_current_user),
):
    return await request_service.list_requests(page, limit, category_id, status)


@router.get("/nearby")
async def get_nearby(
    lat: float,
    lng: float,
    radius_km: float = 20.0,
    current_user=Depends(get_current_user),
):
    return await request_service.get_nearby(lat, lng, radius_km)


@router.get("/{request_id}")
async def get_request(request_id: str, current_user=Depends(get_current_user)):
    return await request_service.get_one(request_id)


@router.put("/{request_id}")
async def update_request(request_id: str, body: ServiceRequestUpdate, current_user=Depends(get_current_user)):
    return await request_service.update(request_id, body, current_user)


@router.delete("/{request_id}")
async def delete_request(request_id: str, current_user=Depends(get_current_user)):
    return await request_service.delete(request_id, current_user)


@router.patch("/{request_id}/status")
async def update_status(request_id: str, body: StatusUpdate, current_user=Depends(get_current_user)):
    return await request_service.update_status(request_id, body, current_user)

from fastapi import HTTPException, status
from datetime import datetime, timezone
from typing import Optional
from app.models.service_request import ServiceRequest
from app.models.user import User
from app.schemas.service_request import ServiceRequestCreate, ServiceRequestUpdate, StatusUpdate
from app.schemas.common import MessageResponse
from app.services.geo_service import haversine_distance
from app.utils.pagination import paginate


async def create(body: ServiceRequestCreate, user: User) -> ServiceRequest:
    req = ServiceRequest(client_id=str(user.id), **body.model_dump())
    await req.insert()
    return req


async def list_requests(page: int = 1, limit: int = 20, category_id: Optional[str] = None, req_status: Optional[str] = None) -> dict:
    filters = []
    if category_id:
        filters.append(ServiceRequest.category_id == category_id)
    if req_status:
        filters.append(ServiceRequest.status == req_status)
    query = ServiceRequest.find(*filters).sort(-ServiceRequest.created_at)
    return await paginate(query, page, limit)


async def get_nearby(user_lat: float, user_lng: float, radius_km: float = 20.0) -> list:
    all_requests = await ServiceRequest.find(ServiceRequest.status == "open").to_list()
    return [
        r for r in all_requests
        if r.location and
        haversine_distance(user_lat, user_lng, r.location.lat, r.location.lng) <= radius_km
    ]


async def get_one(request_id: str) -> ServiceRequest:
    req = await ServiceRequest.get(request_id)
    if not req:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Demande introuvable")
    return req


async def update(request_id: str, body: ServiceRequestUpdate, user: User) -> ServiceRequest:
    req = await get_one(request_id)
    if req.client_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    data = body.model_dump(exclude_none=True)
    for key, value in data.items():
        setattr(req, key, value)
    req.updated_at = datetime.now(timezone.utc)
    await req.save()
    return req


async def delete(request_id: str, user: User) -> MessageResponse:
    req = await get_one(request_id)
    if req.client_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    await req.delete()
    return MessageResponse(message="Demande supprimée")


async def update_status(request_id: str, body: StatusUpdate, user: User) -> ServiceRequest:
    req = await get_one(request_id)
    req.status = body.status
    req.updated_at = datetime.now(timezone.utc)
    await req.save()
    return req

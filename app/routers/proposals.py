from fastapi import APIRouter, Depends
from app.schemas.proposal import ProposalCreate
from app.services import proposal_service
from app.core.security import get_current_user, get_provider_user

router = APIRouter()


@router.post("", status_code=201)
async def submit_proposal(body: ProposalCreate, current_user=Depends(get_provider_user)):
    return await proposal_service.submit(body, current_user)


@router.get("/request/{request_id}")
async def list_by_request(request_id: str, page: int = 1, limit: int = 20, current_user=Depends(get_current_user)):
    return await proposal_service.list_by_request(request_id, page, limit)


@router.get("/mine")
async def my_proposals(page: int = 1, limit: int = 20, current_user=Depends(get_provider_user)):
    return await proposal_service.my_proposals(current_user, page, limit)


@router.post("/{proposal_id}/accept")
async def accept_proposal(proposal_id: str, current_user=Depends(get_current_user)):
    return await proposal_service.accept(proposal_id, current_user)


@router.post("/{proposal_id}/decline")
async def decline_proposal(proposal_id: str, current_user=Depends(get_current_user)):
    return await proposal_service.decline(proposal_id, current_user)


@router.delete("/{proposal_id}")
async def delete_proposal(proposal_id: str, current_user=Depends(get_provider_user)):
    return await proposal_service.delete(proposal_id, current_user)

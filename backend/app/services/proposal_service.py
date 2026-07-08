from fastapi import HTTPException, status
from app.models.proposal import Proposal
from app.models.service_request import ServiceRequest
from app.models.user import User
from app.schemas.proposal import ProposalCreate
from app.schemas.common import MessageResponse
from app.utils.pagination import paginate


async def submit(body: ProposalCreate, user: User) -> Proposal:
    existing = await Proposal.find_one(
        Proposal.request_id == body.request_id,
        Proposal.provider_id == str(user.id),
    )
    if existing:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Vous avez déjà soumis une proposition sur cette demande")
    proposal = Proposal(provider_id=str(user.id), **body.model_dump())
    await proposal.insert()
    return proposal


async def list_by_request(request_id: str, page: int = 1, limit: int = 20) -> dict:
    query = Proposal.find(Proposal.request_id == request_id).sort(-Proposal.created_at)
    return await paginate(query, page, limit)


async def my_proposals(user: User, page: int = 1, limit: int = 20) -> dict:
    query = Proposal.find(Proposal.provider_id == str(user.id)).sort(-Proposal.created_at)
    return await paginate(query, page, limit)


async def accept(proposal_id: str, user: User) -> Proposal:
    proposal = await Proposal.get(proposal_id)
    if not proposal:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Proposition introuvable")
    req = await ServiceRequest.get(proposal.request_id)
    if not req or req.client_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    proposal.status = "accepted"
    await proposal.save()
    req.status = "in_progress"
    await req.save()
    return proposal


async def decline(proposal_id: str, user: User) -> Proposal:
    proposal = await Proposal.get(proposal_id)
    if not proposal:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Proposition introuvable")
    req = await ServiceRequest.get(proposal.request_id)
    if not req or req.client_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    proposal.status = "declined"
    await proposal.save()
    return proposal


async def delete(proposal_id: str, user: User) -> MessageResponse:
    proposal = await Proposal.get(proposal_id)
    if not proposal:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Proposition introuvable")
    if proposal.provider_id != str(user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Non autorisé")
    await proposal.delete()
    return MessageResponse(message="Proposition supprimée")

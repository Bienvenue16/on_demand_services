import pytest


@pytest.mark.asyncio
async def test_list_proposals_unauthenticated(client):
    response = await client.get("/proposals/request/000000000000000000000000")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_submit_proposal_unauthenticated(client):
    response = await client.post("/proposals", json={
        "request_id": "000000000000000000000000",
        "message": "Je suis disponible",
    })
    assert response.status_code == 401

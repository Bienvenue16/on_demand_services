import pytest


@pytest.mark.asyncio
async def test_list_requests_unauthenticated(client):
    response = await client.get("/requests")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_get_request_not_found_unauthenticated(client):
    response = await client.get("/requests/000000000000000000000000")
    assert response.status_code == 401

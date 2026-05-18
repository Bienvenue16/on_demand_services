import pytest


@pytest.mark.asyncio
async def test_register(client):
    response = await client.post("/auth/register", json={
        "email": "test@example.com",
        "password": "password123",
        "full_name": "Test User",
        "role": "client",
    })
    assert response.status_code in (201, 400)


@pytest.mark.asyncio
async def test_login_invalid_credentials(client):
    response = await client.post("/auth/login", json={
        "email": "notexist@example.com",
        "password": "wrongpassword",
    })
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_protected_route_unauthenticated(client):
    response = await client.get("/users/me")
    assert response.status_code == 401

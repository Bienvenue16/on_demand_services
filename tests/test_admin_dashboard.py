import pytest

from app.core.security import hash_password
from app.models.user import User, UserRole


async def _create_admin(email: str = "admin@example.com", password: str = "adminpass123") -> User:
    user = User(
        email=email,
        hashed_password=hash_password(password),
        full_name="Admin Test",
        role=UserRole.admin,
        is_verified=True,
    )
    await user.insert()
    return user


async def _login_admin(client, email: str, password: str) -> None:
    response = await client.post(
        "/admin-panel/login",
        data={"username": email, "password": password, "remember_me": ""},
    )
    assert response.status_code == 303


@pytest.mark.asyncio
async def test_dashboard_requires_admin_session(client):
    response = await client.get("/admin/dashboard")
    assert response.status_code in (303, 307)


@pytest.mark.asyncio
async def test_dashboard_renders_stats_after_login(client):
    await _create_admin()
    await _login_admin(client, "admin@example.com", "adminpass123")

    response = await client.get("/admin/dashboard")
    assert response.status_code == 200
    assert "Dashboard admin" in response.text
    assert "Utilisateurs" in response.text


@pytest.mark.asyncio
async def test_broadcast_notification_from_dashboard(client):
    admin = await _create_admin()
    recipient = User(
        email="client@example.com",
        hashed_password=hash_password("password123"),
        full_name="Client Test",
        role=UserRole.client,
        is_verified=True,
    )
    await recipient.insert()

    await _login_admin(client, admin.email, "adminpass123")

    response = await client.post(
        "/admin/dashboard/broadcast",
        data={"title": "Maintenance", "body": "Le site sera indisponible ce soir.", "target": "all"},
    )
    assert response.status_code == 303
    assert "message=" in response.headers["location"]

    from app.models.notification import Notification

    notif = await Notification.find_one(Notification.user_id == str(recipient.id))
    assert notif is not None
    assert notif.title == "Maintenance"

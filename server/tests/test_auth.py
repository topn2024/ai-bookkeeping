"""End-to-end tests for authentication module."""
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class TestUserRegistration:
    """Test cases for user registration."""

    @pytest.mark.asyncio
    async def test_register_with_email_success(
        self, client: AsyncClient, data_factory
    ):
        """Test successful user registration with email."""
        email = data_factory.random_email()
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": "SecurePass123!",
                "nickname": "Test User",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == email
        assert data["user"]["nickname"] == "Test User"

    @pytest.mark.asyncio
    async def test_register_with_phone_success(
        self, client: AsyncClient, data_factory
    ):
        """Test successful user registration with phone."""
        phone = data_factory.random_phone()
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "phone": phone,
                "password": "SecurePass123!",
                "nickname": "Phone User",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user"]["phone"] == phone

    @pytest.mark.asyncio
    async def test_register_duplicate_email_fails(
        self, client: AsyncClient, test_user: User
    ):
        """Test registration with existing email fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": test_user.email,
                "password": "AnotherPass123!",
                "nickname": "Duplicate User",
            },
        )

        assert response.status_code == 400
        assert "already registered" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_register_weak_password_fails(
        self, client: AsyncClient, data_factory
    ):
        """Test registration with weak password fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": data_factory.random_email(),
                "password": "123",  # Too short
                "nickname": "Test User",
            },
        )

        assert response.status_code == 422  # Validation error

    @pytest.mark.asyncio
    async def test_register_invalid_email_fails(self, client: AsyncClient):
        """Test registration with invalid email fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": "not-an-email",
                "password": "SecurePass123!",
                "nickname": "Test User",
            },
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_register_no_email_or_phone_fails(self, client: AsyncClient):
        """Test registration without email or phone fails."""
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "password": "SecurePass123!",
                "nickname": "Test User",
            },
        )

        assert response.status_code == 400


class TestUserLogin:
    """Test cases for user login."""

    @pytest.mark.asyncio
    async def test_login_with_email_success(
        self, client: AsyncClient, test_user: User
    ):
        """Test successful login with email."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": test_user.email,
                "password": "testpassword123",
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == test_user.email

    @pytest.mark.asyncio
    async def test_login_wrong_password_fails(
        self, client: AsyncClient, test_user: User
    ):
        """Test login with wrong password fails."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": test_user.email,
                "password": "wrongpassword",
            },
        )

        assert response.status_code == 401
        assert "incorrect" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_login_nonexistent_user_fails(
        self, client: AsyncClient, data_factory
    ):
        """Test login with nonexistent user fails."""
        response = await client.post(
            "/api/v1/auth/login",
            json={
                "email": data_factory.random_email(),
                "password": "anypassword",
            },
        )

        assert response.status_code == 401


class TestAuthenticatedEndpoints:
    """Test cases for authenticated endpoints."""

    @pytest.mark.asyncio
    async def test_get_current_user_success(
        self, authenticated_client: AsyncClient, test_user: User
    ):
        """Test getting current user info."""
        response = await authenticated_client.get("/api/v1/auth/me")

        assert response.status_code == 200
        data = response.json()
        assert data["email"] == test_user.email
        assert data["nickname"] == test_user.nickname

    @pytest.mark.asyncio
    async def test_get_current_user_without_token_fails(
        self, client: AsyncClient
    ):
        """Test accessing protected endpoint without token fails."""
        response = await client.get("/api/v1/auth/me")

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_refresh_token_success(
        self, authenticated_client: AsyncClient, test_user: User
    ):
        """Test token refresh."""
        response = await authenticated_client.post("/api/v1/auth/refresh")

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user"]["email"] == test_user.email


class TestOAuthEndpoints:
    """Test cases for OAuth endpoints."""

    @pytest.mark.asyncio
    async def test_get_oauth_config(self, client: AsyncClient):
        """Test getting OAuth configuration."""
        response = await client.get("/api/v1/auth/oauth/config")

        assert response.status_code == 200
        data = response.json()
        assert "wechat" in data
        assert "apple" in data
        assert "google" in data
        # Check structure
        assert "enabled" in data["wechat"]
        assert "enabled" in data["apple"]
        assert "enabled" in data["google"]

    @pytest.mark.asyncio
    async def test_get_oauth_providers_authenticated(
        self, authenticated_client: AsyncClient
    ):
        """Test getting OAuth providers for authenticated user."""
        response = await authenticated_client.get("/api/v1/auth/oauth/providers")

        assert response.status_code == 200
        data = response.json()
        assert "providers" in data
        assert "available_providers" in data
        assert isinstance(data["providers"], list)
        assert isinstance(data["available_providers"], list)

    @pytest.mark.asyncio
    async def test_oauth_login_invalid_provider_fails(self, client: AsyncClient):
        """Test OAuth login with invalid provider fails."""
        response = await client.post(
            "/api/v1/auth/oauth/login",
            json={
                "provider": "invalid_provider",
                "code": "test_auth_code",
            },
        )

        assert response.status_code == 400
        assert "invalid" in response.json()["detail"].lower()

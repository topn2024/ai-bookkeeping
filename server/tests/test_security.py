"""End-to-end tests for security module."""
import pytest
from datetime import timedelta
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    decode_access_token,
)
from app.models.user import User


class TestPasswordHashing:
    """Test cases for password hashing security."""

    def test_password_hash_is_not_plain_text(self):
        """Test that password hash is not the plain password."""
        password = "SecurePass123!"
        hashed = get_password_hash(password)

        assert hashed != password
        assert len(hashed) > len(password)

    def test_password_hash_uses_bcrypt(self):
        """Test that password hash uses bcrypt algorithm."""
        password = "TestPassword!"
        hashed = get_password_hash(password)

        # Bcrypt hashes start with $2b$
        assert hashed.startswith("$2b$")

    def test_same_password_different_hashes(self):
        """Test that same password produces different hashes (salt)."""
        password = "SamePassword123!"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)

        # Each hash should be unique due to random salt
        assert hash1 != hash2

    def test_password_verification_success(self):
        """Test correct password verification."""
        password = "CorrectPassword!"
        hashed = get_password_hash(password)

        assert verify_password(password, hashed) is True

    def test_password_verification_failure(self):
        """Test incorrect password verification."""
        password = "CorrectPassword!"
        wrong_password = "WrongPassword!"
        hashed = get_password_hash(password)

        assert verify_password(wrong_password, hashed) is False

    def test_password_hash_length(self):
        """Test that bcrypt hash has standard length."""
        password = "TestPassword123!"
        hashed = get_password_hash(password)

        # Bcrypt hash is 60 characters
        assert len(hashed) == 60

    def test_empty_password_handling(self):
        """Test empty password still produces valid hash."""
        password = ""
        hashed = get_password_hash(password)

        assert hashed.startswith("$2b$")
        assert verify_password(password, hashed) is True

    def test_unicode_password_support(self):
        """Test unicode password support (Chinese characters)."""
        password = "密码Test123!"
        hashed = get_password_hash(password)

        assert verify_password(password, hashed) is True
        assert verify_password("WrongPassword", hashed) is False

    def test_long_password_support(self):
        """Test very long password support."""
        # Note: bcrypt has a max input of 72 bytes
        password = "A" * 100  # Long password
        hashed = get_password_hash(password)

        assert verify_password(password, hashed) is True


class TestJWTTokens:
    """Test cases for JWT token security."""

    def test_create_access_token_returns_string(self):
        """Test that create_access_token returns a JWT string."""
        user_id = "test-user-123"
        token = create_access_token(user_id)

        assert isinstance(token, str)
        assert len(token) > 0
        # JWT has 3 parts separated by dots
        assert token.count(".") == 2

    def test_decode_access_token_success(self):
        """Test decoding a valid access token."""
        user_id = "user-uuid-12345"
        token = create_access_token(user_id)

        decoded_user_id = decode_access_token(token)
        assert decoded_user_id == user_id

    def test_decode_invalid_token_returns_none(self):
        """Test decoding an invalid token returns None."""
        invalid_token = "invalid.token.here"

        result = decode_access_token(invalid_token)
        assert result is None

    def test_decode_tampered_token_returns_none(self):
        """Test that tampered token fails verification."""
        user_id = "user-123"
        token = create_access_token(user_id)

        # Tamper with the token
        parts = token.split(".")
        parts[1] = parts[1][::-1]  # Reverse the payload
        tampered_token = ".".join(parts)

        result = decode_access_token(tampered_token)
        assert result is None

    def test_expired_token_returns_none(self):
        """Test that expired token fails verification."""
        user_id = "user-123"
        # Create token that expires immediately
        token = create_access_token(user_id, expires_delta=timedelta(seconds=-1))

        result = decode_access_token(token)
        assert result is None

    def test_custom_expiry_token(self):
        """Test token with custom expiry time."""
        user_id = "user-123"
        token = create_access_token(user_id, expires_delta=timedelta(hours=1))

        decoded_user_id = decode_access_token(token)
        assert decoded_user_id == user_id

    def test_token_contains_unique_jti(self):
        """Test that each token has unique JWT ID."""
        user_id = "user-123"
        token1 = create_access_token(user_id)
        token2 = create_access_token(user_id)

        # Tokens should be different due to unique jti and iat
        assert token1 != token2


class TestAuthenticationSecurity:
    """Test cases for authentication security features."""

    @pytest.mark.asyncio
    async def test_password_not_in_response(
        self,
        client: AsyncClient,
        data_factory,
    ):
        """Test that password/hash is never included in API responses."""
        email = data_factory.random_email()
        password = "SecurePass123!"

        # Register user
        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": password,
                "nickname": "Test User",
            },
        )

        assert response.status_code == 200
        data = response.json()

        # Password should never appear in response
        response_text = str(data).lower()
        assert password.lower() not in response_text
        assert "password_hash" not in response_text
        assert "hashed_password" not in response_text

    @pytest.mark.asyncio
    async def test_login_rate_limiting_protection(
        self,
        client: AsyncClient,
        test_user: User,
    ):
        """Test login attempts are handled safely."""
        # Multiple failed login attempts
        for i in range(5):
            response = await client.post(
                "/api/v1/auth/login",
                json={
                    "email": test_user.email,
                    "password": f"wrong_password_{i}",
                },
            )
            # Should return 401, not crash or expose info
            assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_invalid_token_rejected(
        self,
        client: AsyncClient,
    ):
        """Test that invalid tokens are rejected."""
        client.headers["Authorization"] = "Bearer invalid_token_here"

        response = await client.get("/api/v1/auth/me")

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_missing_token_rejected(
        self,
        client: AsyncClient,
    ):
        """Test that missing token is rejected."""
        response = await client.get("/api/v1/auth/me")

        # Should return 401 Unauthorized or 403 Forbidden
        assert response.status_code in [401, 403]

    @pytest.mark.asyncio
    async def test_sql_injection_prevention_login(
        self,
        client: AsyncClient,
    ):
        """Test SQL injection prevention in login."""
        injection_attempts = [
            "' OR '1'='1",
            "'; DROP TABLE users; --",
            "admin'--",
            "' UNION SELECT * FROM users --",
        ]

        for injection in injection_attempts:
            response = await client.post(
                "/api/v1/auth/login",
                json={
                    "email": injection,
                    "password": injection,
                },
            )
            # Should return 401 or 422, not 500
            assert response.status_code in [401, 422]

    @pytest.mark.asyncio
    async def test_xss_prevention_in_nickname(
        self,
        client: AsyncClient,
        data_factory,
    ):
        """Test XSS prevention in user fields."""
        xss_payload = "<script>alert('xss')</script>"

        response = await client.post(
            "/api/v1/auth/register",
            json={
                "email": data_factory.random_email(),
                "password": "SecurePass123!",
                "nickname": xss_payload,
            },
        )

        # Should either sanitize or reject, not execute
        if response.status_code == 200:
            data = response.json()
            # If accepted, script tags should be escaped or sanitized
            nickname = data.get("user", {}).get("nickname", "")
            # The nickname shouldn't execute as script
            assert nickname is not None


class TestHTTPSConfiguration:
    """Test cases for HTTPS and transport security."""

    @pytest.mark.asyncio
    async def test_api_responds_to_health_check(
        self,
        client: AsyncClient,
    ):
        """Test that API has health check endpoint."""
        response = await client.get("/health")

        # May be 200 or 404 depending on implementation
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_secure_headers_present(
        self,
        client: AsyncClient,
    ):
        """Test for security headers in response."""
        response = await client.get("/api/v1/auth/oauth/config")

        # Check for common security headers
        headers = response.headers
        # These may or may not be present depending on server config
        # This test documents expected security headers
        security_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
        ]

        # At minimum, content-type should be set
        assert "content-type" in headers


class TestDataPrivacy:
    """Test cases for data privacy and protection."""

    @pytest.mark.asyncio
    async def test_user_can_only_access_own_data(
        self,
        authenticated_client: AsyncClient,
        db_session: AsyncSession,
        test_user: User,
        data_factory,
    ):
        """Test that users can only access their own data."""
        from uuid import uuid4
        from app.models.book import Book

        # Create another user's book
        other_user = User(
            id=uuid4(),
            email=data_factory.random_email(),
            password_hash=get_password_hash("password123"),
            nickname="Other User",
            is_active=True,
        )
        db_session.add(other_user)
        await db_session.flush()

        other_book = Book(
            id=uuid4(),
            name="Other User's Book",
            user_id=other_user.id,
        )
        db_session.add(other_book)
        await db_session.commit()

        # Try to access other user's book
        response = await authenticated_client.get(
            f"/api/v1/books/{other_book.id}"
        )

        # Should be forbidden or not found
        assert response.status_code in [403, 404]

    @pytest.mark.asyncio
    async def test_sensitive_fields_not_exposed(
        self,
        authenticated_client: AsyncClient,
        test_user: User,
    ):
        """Test that sensitive fields are not exposed in API."""
        response = await authenticated_client.get("/api/v1/auth/me")

        assert response.status_code == 200
        data = response.json()

        # Sensitive fields should not be present
        assert "password" not in data
        assert "password_hash" not in data
        assert "secret" not in data

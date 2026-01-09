"""Signed URL service for secure file downloads.

Generates time-limited signed URLs to prevent hotlinking and unauthorized access.
"""
import hashlib
import hmac
import base64
import time
from datetime import datetime, timedelta
from typing import Optional
from urllib.parse import urlencode, urlparse, parse_qs

from app.core.config import settings


class SignedUrlService:
    """Service for generating and validating signed URLs."""

    # Default expiration time (1 hour)
    DEFAULT_EXPIRE_SECONDS = 3600

    # Maximum expiration time (24 hours)
    MAX_EXPIRE_SECONDS = 86400

    def __init__(self, secret_key: Optional[str] = None):
        """Initialize the service.

        Args:
            secret_key: Secret key for signing. Uses settings.SECRET_KEY if not provided.
        """
        self._secret_key = secret_key or settings.SECRET_KEY
        if not self._secret_key:
            raise ValueError("SECRET_KEY is required for signed URLs")

    def generate_signature(
        self,
        url: str,
        expires: int,
        user_id: Optional[str] = None,
    ) -> str:
        """Generate HMAC signature for a URL.

        Args:
            url: The URL to sign (without query parameters for signature)
            expires: Expiration timestamp (Unix time)
            user_id: Optional user ID to bind the signature to

        Returns:
            Base64-encoded signature string
        """
        # Build the string to sign
        sign_parts = [url, str(expires)]
        if user_id:
            sign_parts.append(user_id)

        sign_string = "|".join(sign_parts)

        # Generate HMAC-SHA256 signature
        signature = hmac.new(
            self._secret_key.encode("utf-8"),
            sign_string.encode("utf-8"),
            hashlib.sha256
        ).digest()

        # Return URL-safe base64 encoded signature
        return base64.urlsafe_b64encode(signature).decode("utf-8").rstrip("=")

    def create_signed_url(
        self,
        original_url: str,
        expire_seconds: int = DEFAULT_EXPIRE_SECONDS,
        user_id: Optional[str] = None,
    ) -> str:
        """Create a signed URL with expiration.

        Args:
            original_url: The original file URL to sign
            expire_seconds: How many seconds until the URL expires
            user_id: Optional user ID to bind the URL to

        Returns:
            Signed URL with expiration and signature parameters
        """
        # Cap expiration time
        expire_seconds = min(expire_seconds, self.MAX_EXPIRE_SECONDS)

        # Calculate expiration timestamp
        expires = int(time.time()) + expire_seconds

        # Parse original URL
        parsed = urlparse(original_url)
        base_url = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"

        # Generate signature
        signature = self.generate_signature(base_url, expires, user_id)

        # Build query parameters
        params = {}
        if parsed.query:
            params = dict(parse_qs(parsed.query, keep_blank_values=True))
            # Flatten single-value lists
            params = {k: v[0] if len(v) == 1 else v for k, v in params.items()}

        params["expires"] = str(expires)
        params["sign"] = signature
        if user_id:
            params["uid"] = user_id

        # Construct signed URL
        return f"{base_url}?{urlencode(params)}"

    def validate_signature(
        self,
        url: str,
        signature: str,
        expires: int,
        user_id: Optional[str] = None,
    ) -> bool:
        """Validate a URL signature.

        Args:
            url: The base URL (without signature params)
            signature: The signature to validate
            expires: Expiration timestamp from the URL
            user_id: User ID from the URL (if present)

        Returns:
            True if signature is valid and not expired
        """
        # Check expiration
        if expires < int(time.time()):
            return False

        # Generate expected signature
        expected = self.generate_signature(url, expires, user_id)

        # Use constant-time comparison to prevent timing attacks
        return hmac.compare_digest(signature, expected)

    def is_url_valid(self, signed_url: str) -> bool:
        """Check if a signed URL is valid.

        Args:
            signed_url: The full signed URL to validate

        Returns:
            True if the URL is valid and not expired
        """
        try:
            parsed = urlparse(signed_url)
            base_url = f"{parsed.scheme}://{parsed.netloc}{parsed.path}"

            # Parse query parameters
            params = parse_qs(parsed.query)

            # Get required parameters
            expires_list = params.get("expires", [])
            sign_list = params.get("sign", [])

            if not expires_list or not sign_list:
                return False

            expires = int(expires_list[0])
            signature = sign_list[0]
            uid_list = params.get("uid", [])
            user_id = uid_list[0] if uid_list else None

            return self.validate_signature(base_url, signature, expires, user_id)

        except (ValueError, KeyError, IndexError):
            return False


# Global instance
_signed_url_service: Optional[SignedUrlService] = None


def get_signed_url_service() -> SignedUrlService:
    """Get or create the signed URL service instance."""
    global _signed_url_service
    if _signed_url_service is None:
        _signed_url_service = SignedUrlService()
    return _signed_url_service


def create_download_url(
    file_url: str,
    expire_seconds: int = SignedUrlService.DEFAULT_EXPIRE_SECONDS,
    user_id: Optional[str] = None,
) -> str:
    """Convenience function to create a signed download URL.

    Args:
        file_url: Original file URL
        expire_seconds: URL validity period in seconds
        user_id: Optional user ID to bind the URL to

    Returns:
        Signed download URL
    """
    return get_signed_url_service().create_signed_url(
        file_url,
        expire_seconds=expire_seconds,
        user_id=user_id,
    )


def validate_download_url(signed_url: str) -> bool:
    """Convenience function to validate a signed download URL.

    Args:
        signed_url: The signed URL to validate

    Returns:
        True if valid and not expired
    """
    return get_signed_url_service().is_url_valid(signed_url)

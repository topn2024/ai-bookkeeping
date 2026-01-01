"""Security utilities for authentication."""
from datetime import datetime, timedelta
from typing import Optional
import base64
import hashlib
import uuid

from jose import JWTError, jwt
from passlib.context import CryptContext
from cryptography.fernet import Fernet

from app.core.config import settings


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def _get_fernet_key() -> bytes:
    """Derive a Fernet key from JWT_SECRET_KEY."""
    # Use SHA-256 to hash the secret key and then base64 encode it
    # Fernet requires a 32-byte base64-encoded key
    key_bytes = settings.JWT_SECRET_KEY.encode('utf-8')
    hashed = hashlib.sha256(key_bytes).digest()
    return base64.urlsafe_b64encode(hashed)


def _get_fernet() -> Fernet:
    """Get Fernet instance for encryption/decryption."""
    return Fernet(_get_fernet_key())


def encrypt_sensitive_data(plaintext: str) -> str:
    """Encrypt sensitive data (like IMAP passwords) using Fernet.

    Args:
        plaintext: The string to encrypt

    Returns:
        Base64 encoded encrypted string
    """
    if not plaintext:
        return plaintext

    fernet = _get_fernet()
    encrypted = fernet.encrypt(plaintext.encode('utf-8'))
    return encrypted.decode('utf-8')


def decrypt_sensitive_data(ciphertext: str) -> str:
    """Decrypt sensitive data that was encrypted with encrypt_sensitive_data.

    Args:
        ciphertext: The base64 encoded encrypted string

    Returns:
        The original plaintext string
    """
    if not ciphertext:
        return ciphertext

    try:
        fernet = _get_fernet()
        decrypted = fernet.decrypt(ciphertext.encode('utf-8'))
        return decrypted.decode('utf-8')
    except Exception:
        # Return original if decryption fails (might be unencrypted legacy data)
        return ciphertext


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Generate password hash."""
    return pwd_context.hash(password)


def create_access_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token."""
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode = {
        "sub": user_id,
        "type": "access",
        "exp": expire,
        "iat": datetime.utcnow(),
        "jti": str(uuid.uuid4()),
    }
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def create_refresh_token(user_id: str, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT refresh token with longer expiration."""
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        # Refresh token expires in 30 days
        expire = datetime.utcnow() + timedelta(days=30)

    to_encode = {
        "sub": user_id,
        "type": "refresh",
        "exp": expire,
        "iat": datetime.utcnow(),
        "jti": str(uuid.uuid4()),
    }
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt


def decode_refresh_token(token: str) -> Optional[str]:
    """Decode JWT refresh token and return user_id if valid."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        # Verify this is a refresh token
        if payload.get("type") != "refresh":
            return None
        user_id: str = payload.get("sub")
        if user_id is None:
            return None
        return user_id
    except JWTError:
        return None


def decode_access_token(token: str) -> Optional[str]:
    """Decode JWT access token and return user_id."""
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            return None
        return user_id
    except JWTError:
        return None

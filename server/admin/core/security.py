"""Security utilities for admin authentication."""
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from uuid import UUID

from passlib.context import CryptContext
from jose import JWTError, jwt

from app.core.config import settings


# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT settings
ADMIN_SECRET_KEY = settings.SECRET_KEY + "_admin"  # 使用独立的密钥
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 120  # 2小时


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """生成密码哈希"""
    return pwd_context.hash(password)


def create_access_token(
    data: Dict[str, Any],
    expires_delta: Optional[timedelta] = None
) -> str:
    """创建JWT Token"""
    to_encode = data.copy()

    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "admin_access",
    })

    encoded_jwt = jwt.encode(to_encode, ADMIN_SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def decode_access_token(token: str) -> Optional[Dict[str, Any]]:
    """解码JWT Token"""
    try:
        payload = jwt.decode(token, ADMIN_SECRET_KEY, algorithms=[ALGORITHM])

        # 验证token类型
        if payload.get("type") != "admin_access":
            return None

        return payload
    except JWTError:
        return None


def create_refresh_token(admin_id: UUID) -> str:
    """创建刷新Token"""
    expire = datetime.utcnow() + timedelta(days=7)

    to_encode = {
        "sub": str(admin_id),
        "exp": expire,
        "iat": datetime.utcnow(),
        "type": "admin_refresh",
    }

    return jwt.encode(to_encode, ADMIN_SECRET_KEY, algorithm=ALGORITHM)


def decode_refresh_token(token: str) -> Optional[str]:
    """解码刷新Token，返回admin_id"""
    try:
        payload = jwt.decode(token, ADMIN_SECRET_KEY, algorithms=[ALGORITHM])

        if payload.get("type") != "admin_refresh":
            return None

        return payload.get("sub")
    except JWTError:
        return None

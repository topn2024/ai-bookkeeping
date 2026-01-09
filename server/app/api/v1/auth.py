"""Authentication endpoints."""
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.redis import get_redis
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
)
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.schemas.user import (
    UserCreate, UserLogin, UserResponse, Token, RefreshTokenRequest,
    UserUpdate, CheckEmailRequest, CheckEmailResponse,
    ResetPasswordRequest, ResetPasswordResponse, ResetPasswordConfirm,
)
from app.api.deps import get_current_user
from app.services.init_service import init_user_data
from app.services.notification_email_service import notification_email_service
import secrets
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=Token)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
):
    """Register a new user."""
    # Check if phone or email already exists
    if user_data.phone:
        result = await db.execute(select(User).where(User.phone == user_data.phone))
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Phone number already registered",
            )

    if user_data.email:
        result = await db.execute(select(User).where(User.email == user_data.email))
        if result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered",
            )

    if not user_data.phone and not user_data.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone or email is required",
        )

    # Create user
    user = User(
        phone=user_data.phone,
        email=user_data.email,
        password_hash=get_password_hash(user_data.password),
        nickname=user_data.nickname or (user_data.phone[:3] + "****" + user_data.phone[-4:] if user_data.phone else "User"),
    )
    db.add(user)
    await db.flush()

    # Initialize user data (default book, accounts, etc.)
    await init_user_data(db, user)

    await db.commit()
    await db.refresh(user)

    # Generate tokens
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post("/login", response_model=Token)
async def login(
    login_data: UserLogin,
    db: AsyncSession = Depends(get_db),
):
    """Login with phone/email and password."""
    # Find user
    query = select(User)
    if login_data.phone:
        query = query.where(User.phone == login_data.phone)
    elif login_data.email:
        query = query.where(User.email == login_data.email)
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone or email is required",
        )

    result = await db.execute(query)
    user = result.scalar_one_or_none()

    if not user or not verify_password(login_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect credentials",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is inactive",
        )

    # Generate tokens
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    """Get current user info."""
    return UserResponse.model_validate(current_user)


@router.post("/refresh", response_model=Token)
async def refresh_token_endpoint(
    request: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Refresh access token using refresh token."""
    # Decode and validate refresh token
    user_id = decode_refresh_token(request.refresh_token)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Get user from database
    try:
        user_uuid = UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    result = await db.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is inactive",
        )

    # Generate new tokens
    access_token = create_access_token(str(user.id))
    new_refresh_token = create_refresh_token(str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=new_refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post("/check-email", response_model=CheckEmailResponse)
async def check_email(
    request: CheckEmailRequest,
    db: AsyncSession = Depends(get_db),
):
    """Check if email is already registered."""
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()

    if user:
        return CheckEmailResponse(
            exists=True,
            message="Email is already registered",
        )
    return CheckEmailResponse(
        exists=False,
        message="Email is available",
    )


@router.post("/reset-password", response_model=ResetPasswordResponse)
async def request_password_reset(
    request: ResetPasswordRequest,
    db: AsyncSession = Depends(get_db),
):
    """Request password reset. Generates a reset code and sends it via email."""
    import time

    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()

    if not user:
        # Don't reveal if email exists or not for security
        return ResetPasswordResponse(
            success=True,
            message="If the email exists, a reset code has been sent",
        )

    # Generate 6-digit reset code
    code = ''.join([str(secrets.randbelow(10)) for _ in range(6)])

    # Store the code in Redis with 10 minutes TTL
    redis = await get_redis()
    if redis:
        reset_key = f"password_reset:{request.email}"
        await redis.setex(reset_key, 600, code)  # 600 seconds = 10 minutes
    else:
        logger.error("Redis not available for password reset")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable",
        )

    # Send email with the code
    email_sent = await notification_email_service.send_password_reset_code(
        to_email=request.email,
        reset_code=code,
        expires_minutes=10,
    )

    if not email_sent:
        # Log for debugging but don't reveal to user
        logger.warning(f"Failed to send password reset email to {request.email}")

    return ResetPasswordResponse(
        success=True,
        message="If the email exists, a reset code has been sent",
    )


@router.post("/reset-password/confirm", response_model=ResetPasswordResponse)
async def confirm_password_reset(
    request: ResetPasswordConfirm,
    db: AsyncSession = Depends(get_db),
):
    """Confirm password reset with the code received via email."""
    # Get code from Redis
    redis = await get_redis()
    if not redis:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable",
        )

    reset_key = f"password_reset:{request.email}"
    stored_code = await redis.get(reset_key)

    if not stored_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset code",
        )

    # Decode bytes to string
    if isinstance(stored_code, bytes):
        stored_code = stored_code.decode('utf-8')

    if request.code != stored_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reset code",
        )

    # Update password
    result = await db.execute(select(User).where(User.email == request.email))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    user.password_hash = get_password_hash(request.new_password)
    await db.commit()

    # Remove used code from Redis
    await redis.delete(reset_key)

    return ResetPasswordResponse(
        success=True,
        message="Password has been reset successfully",
    )


@router.patch("/me", response_model=UserResponse)
async def update_me(
    user_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update current user's profile."""
    if user_data.nickname is not None:
        current_user.nickname = user_data.nickname
    if user_data.avatar_url is not None:
        current_user.avatar_url = user_data.avatar_url

    await db.commit()
    await db.refresh(current_user)

    return UserResponse.model_validate(current_user)

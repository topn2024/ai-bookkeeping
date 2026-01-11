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
    SendSmsCodeRequest, SendSmsCodeResponse, SmsLoginRequest,
)
from app.api.deps import get_current_user
from app.services.init_service import init_user_data
from app.services.notification_email_service import notification_email_service
from app.services.notification_sms_service import notification_sms_service
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
        # Log code in debug mode for testing (REMOVE IN PRODUCTION)
        from app.core.config import settings
        if settings.DEBUG:
            logger.info(f"[DEV] Password reset code for {request.email}: {code}")
    else:
        logger.error("Redis not available for password reset")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable",
        )

    # Send email with the code
    logger.info(f"Attempting to send password reset email to {request.email}")

    # Check if email service is configured
    if not notification_email_service.is_configured:
        from app.core.config import settings as app_settings
        logger.error("Email service is not configured! Missing SMTP settings.")
        logger.error(f"SMTP_HOST: {app_settings.SMTP_HOST}")
        logger.error(f"SMTP_USER: {app_settings.SMTP_USER}")
        logger.error(f"SMTP_PASSWORD: {'***SET***' if app_settings.SMTP_PASSWORD else 'NOT SET'}")

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

    # Update password hash
    user.password_hash = get_password_hash(request.new_password)
    db.add(user)  # Explicitly add to session to ensure tracking

    try:
        await db.commit()
        logger.info(f"Password reset successful for user: {request.email}")
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to update password for {request.email}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to reset password",
        )

    # Remove used code from Redis
    try:
        await redis.delete(reset_key)
    except Exception as e:
        logger.warning(f"Failed to delete reset code from Redis: {e}")
        # Don't fail the request if Redis cleanup fails

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


@router.post("/sms-code", response_model=SendSmsCodeResponse)
async def send_sms_code(
    request: SendSmsCodeRequest,
    db: AsyncSession = Depends(get_db),
):
    """Send SMS verification code.

    发送短信验证码，支持以下场景：
    - login: 登录
    - register: 注册
    - reset_password: 重置密码

    验证码有效期：10分钟
    """
    # 检查手机号是否已注册（根据场景判断）
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()

    if request.scene == "register" and user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered",
        )

    if request.scene in ["login", "reset_password"] and not user:
        # 为了安全，不透露手机号是否存在，但仍返回成功
        return SendSmsCodeResponse(
            success=True,
            message="验证码已发送（如果该手机号已注册）",
            expires_in=600,
        )

    # 生成6位随机验证码
    code = ''.join([str(secrets.randbelow(10)) for _ in range(6)])

    # 存储验证码到Redis，有效期10分钟
    redis = await get_redis()
    if not redis:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable",
        )

    # Redis key格式：sms_code:{scene}:{phone}
    sms_key = f"sms_code:{request.scene}:{request.phone}"
    await redis.setex(sms_key, 600, code)  # 600秒 = 10分钟

    # 调试模式下记录验证码（生产环境移除）
    from app.core.config import settings
    if settings.DEBUG:
        logger.info(f"[DEV] SMS code for {request.phone} ({request.scene}): {code}")

    # 发送短信
    sms_sent = await notification_sms_service.send_verification_code(
        phone_number=request.phone,
        code=code,
    )

    if not sms_sent:
        logger.warning(f"Failed to send SMS to {request.phone}")
        # 不向用户透露失败详情

    return SendSmsCodeResponse(
        success=True,
        message="验证码已发送，请注意查收短信",
        expires_in=600,
    )


@router.post("/sms-login", response_model=Token)
async def sms_login(
    request: SmsLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """Login with phone number and SMS verification code.

    使用手机号和短信验证码登录：
    - 如果用户不存在且 auto_register=True，则自动注册
    - 如果用户不存在且 auto_register=False，则返回错误
    - 验证码验证成功后自动删除
    """
    # 从Redis验证验证码
    redis = await get_redis()
    if not redis:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable",
        )

    # 检查验证码（登录场景）
    sms_key = f"sms_code:login:{request.phone}"
    stored_code = await redis.get(sms_key)

    if not stored_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码无效或已过期",
        )

    # 解码验证码
    if isinstance(stored_code, bytes):
        stored_code = stored_code.decode('utf-8')

    if request.code != stored_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误",
        )

    # 查找用户
    result = await db.execute(select(User).where(User.phone == request.phone))
    user = result.scalar_one_or_none()

    # 如果用户不存在
    if not user:
        if not request.auto_register:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found. Set auto_register=true to create account.",
            )

        # 自动注册新用户
        user = User(
            phone=request.phone,
            nickname=f"用户{request.phone[-4:]}",  # 默认昵称：用户+后4位
            is_active=True,
        )
        db.add(user)
        await db.flush()

        # 初始化用户数据（默认账本、账户等）
        await init_user_data(db, user)

        await db.commit()
        await db.refresh(user)

        logger.info(f"Auto-registered new user via SMS: {request.phone}")

    # 检查用户是否激活
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is inactive",
        )

    # 删除已使用的验证码
    try:
        await redis.delete(sms_key)
    except Exception as e:
        logger.warning(f"Failed to delete SMS code from Redis: {e}")

    # 生成JWT令牌
    access_token = create_access_token(str(user.id))
    refresh_token = create_refresh_token(str(user.id))

    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )

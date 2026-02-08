"""Authentication endpoints."""
import asyncio
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from app.core.redis import get_redis
from app.core.config import settings
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    create_email_verification_token,
    decode_email_verification_token,
)
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.schemas.user import (
    UserCreate, UserLogin, UserResponse, Token, RefreshTokenRequest,
    UserUpdate, CheckEmailRequest, CheckEmailResponse,
    ResetPasswordRequest, ResetPasswordResponse, ResetPasswordConfirm,
    SendSmsCodeRequest, SendSmsCodeResponse, SmsLoginRequest,
    SendVerificationEmailResponse, VerifyEmailResponse, EmailVerificationStatusResponse,
)
from app.api.deps import get_current_user
from app.services.init_service import init_user_data
from app.services.notification_email_service import notification_email_service
from app.services.notification_sms_service import notification_sms_service
import secrets
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _mask_email(email: str) -> str:
    """Mask email for logging: user@example.com -> u***@example.com"""
    if not email or "@" not in email:
        return "***"
    local, domain = email.rsplit("@", 1)
    return f"{local[0]}***@{domain}" if local else f"***@{domain}"


def _mask_phone(phone: str) -> str:
    """Mask phone for logging: 13812345678 -> 138****5678"""
    if not phone or len(phone) < 7:
        return "***"
    return f"{phone[:3]}****{phone[-4:]}"


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
        email_verified=False,
    )
    db.add(user)
    await db.flush()

    # Initialize user data (default book, accounts, etc.)
    await init_user_data(db, user)

    await db.commit()
    await db.refresh(user)

    # 如果注册时填写了邮箱，异步发送验证邮件（不阻塞注册流程）
    if user_data.email:
        try:
            verification_token = create_email_verification_token(str(user.id), user_data.email)
            verification_url = f"{settings.APP_BASE_URL}/api/v1/auth/verify-email?token={verification_token}"

            # 异步发送邮件
            asyncio.create_task(
                notification_email_service.send_email_verification(
                    to_email=user_data.email,
                    verification_url=verification_url,
                    expires_minutes=60,
                )
            )
            logger.info(f"Verification email queued for {_mask_email(user_data.email)}")
        except Exception as e:
            # 发送失败不影响注册
            logger.warning(f"Failed to queue verification email for {_mask_email(user_data.email)}: {e}")

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
            logger.info(f"[DEV] Password reset code for {_mask_email(request.email)}: {code}")
    else:
        logger.error("Redis not available for password reset")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service temporarily unavailable",
        )

    # Send email with the code
    logger.info(f"Attempting to send password reset email to {_mask_email(request.email)}")

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
        logger.warning(f"Failed to send password reset email to {_mask_email(request.email)}")

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
        logger.info(f"Password reset successful for user: {_mask_email(request.email)}")
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to update password for {_mask_email(request.email)}: {e}")
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
        logger.info(f"[DEV] SMS code for {_mask_phone(request.phone)} ({request.scene}): {code}")

    # 发送短信
    sms_sent = await notification_sms_service.send_verification_code(
        phone_number=request.phone,
        code=code,
    )

    if not sms_sent:
        logger.warning(f"Failed to send SMS to {_mask_phone(request.phone)}")
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

        logger.info(f"Auto-registered new user via SMS: {_mask_phone(request.phone)}")

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


@router.post("/send-verification-email", response_model=SendVerificationEmailResponse)
async def send_verification_email(
    current_user: User = Depends(get_current_user),
):
    """发送邮箱验证邮件。

    需要登录。如果用户已有邮箱且未验证，发送验证邮件。
    支持重新发送（每小时最多5次）。
    """
    if not current_user.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No email address to verify",
        )

    # 检查是否已验证
    if current_user.email_verified:
        return SendVerificationEmailResponse(
            success=True,
            message="Email already verified",
            expires_in=0,
        )

    # 检查发送频率限制（每用户每小时最多5次）
    redis = await get_redis()
    if redis:
        rate_key = f"email_verify:rate:{current_user.id}"
        send_count = await redis.incr(rate_key)
        if send_count == 1:
            await redis.expire(rate_key, 3600)  # 1小时窗口
        elif send_count > 5:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many verification emails sent. Please try again later.",
            )

    # 生成验证 token
    token = create_email_verification_token(str(current_user.id), current_user.email)

    # 构建验证 URL
    verification_url = f"{settings.APP_BASE_URL}/api/v1/auth/verify-email?token={token}"

    # 发送邮件
    email_sent = await notification_email_service.send_email_verification(
        to_email=current_user.email,
        verification_url=verification_url,
        expires_minutes=60,
    )

    if not email_sent:
        logger.warning(f"Failed to send verification email to {_mask_email(current_user.email)}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to send verification email. Please try again later.",
        )

    logger.info(f"Verification email sent to {_mask_email(current_user.email)}")
    return SendVerificationEmailResponse(
        success=True,
        message="Verification email sent. Please check your inbox.",
        expires_in=3600,
    )


@router.get("/verify-email", response_model=VerifyEmailResponse)
async def verify_email(
    token: str,
    db: AsyncSession = Depends(get_db),
):
    """验证邮箱。

    用户点击邮件中的链接后调用此端点。
    成功后更新用户的 email_verified 状态。
    """
    # 解码 token
    token_data = decode_email_verification_token(token)

    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification link",
        )

    user_id = token_data["user_id"]
    email = token_data["email"]
    jti = token_data["jti"]

    # 检查 token 是否已使用
    redis = await get_redis()
    if redis:
        used_key = f"email_verify:used:{jti}"
        if await redis.exists(used_key):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This verification link has already been used",
            )

    # 查找用户
    try:
        user_uuid = UUID(user_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification link",
        )

    result = await db.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    # 检查邮箱是否匹配（防止用新token验证旧邮箱）
    if user.email != email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email address mismatch. Please request a new verification email.",
        )

    # 检查是否已验证
    if user.email_verified:
        return VerifyEmailResponse(
            success=True,
            message="Email already verified",
            email=email,
        )

    # 更新验证状态
    user.email_verified = True
    user.email_verified_at = datetime.utcnow()

    try:
        await db.commit()
        logger.info(f"Email verified for user {user_id}: {_mask_email(email)}")
    except Exception as e:
        await db.rollback()
        logger.error(f"Failed to verify email for {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to verify email",
        )

    # 标记 token 为已使用
    if redis:
        await redis.setex(f"email_verify:used:{jti}", 3600, "1")

    return VerifyEmailResponse(
        success=True,
        message="Email verified successfully",
        email=email,
    )


@router.get("/email-verification-status", response_model=EmailVerificationStatusResponse)
async def get_email_verification_status(
    current_user: User = Depends(get_current_user),
):
    """获取当前用户的邮箱验证状态。"""
    return EmailVerificationStatusResponse(
        email=current_user.email,
        is_verified=current_user.email_verified,
        verified_at=current_user.email_verified_at,
    )

"""Admin authentication endpoints."""
import logging
from collections import defaultdict
from datetime import datetime, timedelta
from typing import List, Set
import time

import pyotp
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.models.admin_role import AdminRole
from admin.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
    decode_access_token,
    ACCESS_TOKEN_EXPIRE_MINUTES,
)
from admin.core.audit import create_audit_log
from admin.api.deps import get_current_admin
from admin.schemas.auth import (
    AdminLoginRequest,
    AdminLoginResponse,
    AdminInfo,
    AdminTokenRefreshRequest,
    AdminTokenRefreshResponse,
    PasswordChangeRequest,
)

logger = logging.getLogger(__name__)


# ============ Redis-based Token Blacklist ============
# Try to use Redis for token blacklist; fall back to in-memory if unavailable

_redis_client = None
_redis_available = False

try:
    import redis.asyncio as aioredis
    from app.core.config import settings

    _redis_url = getattr(settings, "REDIS_URL", "")
    if _redis_url:
        _redis_client = aioredis.from_url(
            _redis_url,
            decode_responses=True,
            socket_connect_timeout=3,
        )
        _redis_available = True
        logger.info("Token blacklist: using Redis backend")
except Exception as e:
    logger.warning(f"Token blacklist: Redis unavailable ({e}), falling back to in-memory")

# In-memory fallback (only used when Redis is unavailable)
_token_blacklist_mem: dict[str, float] = {}
_BLACKLIST_CLEANUP_INTERVAL = 300
_last_cleanup_time = time.time()
_BLACKLIST_PREFIX = "admin:token:blacklist:"


async def add_token_to_blacklist(token: str):
    """将token加入黑名单（优先使用Redis）"""
    ttl_seconds = ACCESS_TOKEN_EXPIRE_MINUTES * 60

    # 尝试从token中提取JTI作为key
    payload = decode_access_token(token)
    blacklist_key = payload.get("jti", token) if payload else token

    if _redis_available and _redis_client:
        try:
            await _redis_client.setex(
                f"{_BLACKLIST_PREFIX}{blacklist_key}",
                ttl_seconds,
                "1",
            )
            return
        except Exception as e:
            logger.warning(f"Redis blacklist write failed: {e}, using in-memory fallback")

    # In-memory fallback
    _cleanup_blacklist_mem()
    _token_blacklist_mem[blacklist_key] = time.time() + ttl_seconds


async def is_token_blacklisted(token: str) -> bool:
    """检查token是否在黑名单中"""
    payload = decode_access_token(token)
    blacklist_key = payload.get("jti", token) if payload else token

    if _redis_available and _redis_client:
        try:
            result = await _redis_client.get(f"{_BLACKLIST_PREFIX}{blacklist_key}")
            return result is not None
        except Exception as e:
            logger.warning(f"Redis blacklist read failed: {e}, using in-memory fallback")

    # In-memory fallback
    _cleanup_blacklist_mem()
    if blacklist_key not in _token_blacklist_mem:
        return False
    expire_time = _token_blacklist_mem[blacklist_key]
    if time.time() > expire_time:
        del _token_blacklist_mem[blacklist_key]
        return False
    return True


def _cleanup_blacklist_mem():
    """清理已过期的内存黑名单token"""
    global _last_cleanup_time
    current_time = time.time()
    if current_time - _last_cleanup_time < _BLACKLIST_CLEANUP_INTERVAL:
        return
    _last_cleanup_time = current_time
    expired = [k for k, v in _token_blacklist_mem.items() if current_time > v]
    for k in expired:
        del _token_blacklist_mem[k]


# ============ IP-based Rate Limiting ============

# IP rate limit: max attempts per window
_IP_RATE_LIMIT_MAX = 20  # max 20 login attempts per IP per window
_IP_RATE_LIMIT_WINDOW = 300  # 5-minute window (seconds)
_ip_attempts: dict[str, list] = defaultdict(list)


def _check_ip_rate_limit(ip: str) -> bool:
    """检查IP是否超过速率限制。返回True表示允许，False表示被限制。"""
    now = time.time()
    cutoff = now - _IP_RATE_LIMIT_WINDOW

    # 清理过期记录
    _ip_attempts[ip] = [t for t in _ip_attempts[ip] if t > cutoff]

    if len(_ip_attempts[ip]) >= _IP_RATE_LIMIT_MAX:
        return False

    _ip_attempts[ip].append(now)
    return True


router = APIRouter(prefix="/auth", tags=["Admin Auth"])


# 登录失败锁定配置
MAX_FAILED_ATTEMPTS = 5
LOCKOUT_MINUTES = 15


@router.post("/login", response_model=AdminLoginResponse)
async def login(
    request: Request,
    login_data: AdminLoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """管理员登录"""
    client_ip = _get_client_ip(request)

    # IP级别速率限制
    if not _check_ip_rate_limit(client_ip):
        logger.warning(f"IP rate limit exceeded: {client_ip}")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="登录尝试过于频繁，请稍后再试",
            headers={"Retry-After": str(_IP_RATE_LIMIT_WINDOW)},
        )

    # 查询管理员
    result = await db.execute(
        select(AdminUser)
        .options(selectinload(AdminUser.role).selectinload(AdminRole.permissions))
        .where(AdminUser.username == login_data.username)
    )
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
        )

    # 检查账户是否被锁定
    if admin.is_locked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"账户已锁定，请{LOCKOUT_MINUTES}分钟后重试",
        )

    # 检查账户是否被禁用
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被禁用",
        )

    # 验证密码
    if not verify_password(login_data.password, admin.password_hash):
        # 记录失败次数
        admin.failed_login_count += 1

        # 超过最大失败次数，锁定账户
        if admin.failed_login_count >= MAX_FAILED_ATTEMPTS:
            admin.locked_until = datetime.utcnow() + timedelta(minutes=LOCKOUT_MINUTES)

        await db.commit()

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误",
        )

    # 检查MFA - 统一错误信息，避免泄露MFA启用状态
    if admin.mfa_enabled:
        if not login_data.mfa_code:
            # 不再单独提示"需要MFA验证码"，而是返回统一的认证失败信息
            # 但通过特定的 error code 让前端知道需要 MFA
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用户名或密码错误",
                headers={"X-MFA-Required": "true"},
            )
        # 验证MFA码
        if not admin.mfa_secret:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="认证服务异常，请联系管理员",
            )
        totp = pyotp.TOTP(admin.mfa_secret)
        if not totp.verify(login_data.mfa_code, valid_window=1):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="用户名或密码错误",
            )

    # 登录成功，重置失败计数
    admin.failed_login_count = 0
    admin.locked_until = None
    admin.last_login_at = datetime.utcnow()
    admin.last_login_ip = client_ip
    admin.login_count += 1

    # 获取权限列表
    permissions = _get_permission_codes(admin)

    # 生成Token
    access_token = create_access_token(
        data={"sub": str(admin.id), "username": admin.username}
    )
    refresh_token = create_refresh_token(admin.id)

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=admin.id,
        admin_username=admin.username,
        action="auth.login",
        module="auth",
        description=f"管理员 {admin.username} 登录成功",
        request=request,
    )

    await db.commit()

    return AdminLoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        admin=AdminInfo(
            id=admin.id,
            username=admin.username,
            email=admin.email,
            display_name=admin.display_name,
            avatar_url=admin.avatar_url,
            role_name=admin.role.name if admin.role else "",
            role_display_name=admin.role.display_name if admin.role else "",
            permissions=permissions,
            is_superadmin=admin.is_superadmin,
            mfa_enabled=admin.mfa_enabled,
        ),
    )


@router.post("/refresh", response_model=AdminTokenRefreshResponse)
async def refresh_token(
    request_data: AdminTokenRefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    """刷新Token"""
    admin_id = decode_refresh_token(request_data.refresh_token)

    if not admin_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的刷新令牌",
        )

    # 验证管理员存在且有效
    result = await db.execute(
        select(AdminUser).where(AdminUser.id == admin_id)
    )
    admin = result.scalar_one_or_none()

    if not admin or not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="管理员不存在或已禁用",
        )

    # 生成新Token
    access_token = create_access_token(
        data={"sub": str(admin.id), "username": admin.username}
    )

    return AdminTokenRefreshResponse(
        access_token=access_token,
        token_type="bearer",
        expires_in=ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post("/logout")
async def logout(
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """管理员登出"""
    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="auth.logout",
        module="auth",
        description=f"管理员 {current_admin.username} 登出",
        request=request,
    )

    await db.commit()

    # 将当前Token加入黑名单（Redis-backed）
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        await add_token_to_blacklist(token)

    return {"message": "登出成功"}


@router.post("/password/change")
async def change_password(
    request: Request,
    password_data: PasswordChangeRequest,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
):
    """修改密码"""
    from admin.core.security import validate_password_complexity

    # 验证旧密码
    if not verify_password(password_data.old_password, current_admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="旧密码错误",
        )

    # 验证新密码复杂度
    complexity_errors = validate_password_complexity(password_data.new_password)
    if complexity_errors:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="密码不符合要求: " + "; ".join(complexity_errors),
        )

    # 更新密码
    current_admin.password_hash = get_password_hash(password_data.new_password)

    # 记录审计日志
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="auth.password_change",
        module="auth",
        description=f"管理员 {current_admin.username} 修改密码",
        request=request,
    )

    await db.commit()

    return {"message": "密码修改成功"}


@router.get("/me", response_model=AdminInfo)
async def get_current_admin_info(
    current_admin: AdminUser = Depends(get_current_admin),
):
    """获取当前管理员信息"""
    permissions = _get_permission_codes(current_admin)

    return AdminInfo(
        id=current_admin.id,
        username=current_admin.username,
        email=current_admin.email,
        display_name=current_admin.display_name,
        avatar_url=current_admin.avatar_url,
        role_name=current_admin.role.name if current_admin.role else "",
        role_display_name=current_admin.role.display_name if current_admin.role else "",
        permissions=permissions,
        is_superadmin=current_admin.is_superadmin,
        mfa_enabled=current_admin.mfa_enabled,
    )


def _get_permission_codes(admin: AdminUser) -> List[str]:
    """获取管理员的权限代码列表"""
    if admin.is_superadmin:
        return ["*"]

    if admin.role and admin.role.permissions:
        return [p.code for p in admin.role.permissions]

    return []


def _get_client_ip(request: Request) -> str:
    """获取客户端IP"""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()

    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip

    if request.client:
        return request.client.host

    return "unknown"

"""Audit logging utilities."""
from datetime import datetime
from typing import Optional, Dict, Any
from uuid import UUID

from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from admin.models.admin_log import AdminLog, LOG_ACTIONS


async def create_audit_log(
    db: AsyncSession,
    admin_id: UUID,
    admin_username: str,
    action: str,
    module: str,
    target_type: Optional[str] = None,
    target_id: Optional[str] = None,
    target_name: Optional[str] = None,
    description: Optional[str] = None,
    request_data: Optional[Dict[str, Any]] = None,
    response_data: Optional[Dict[str, Any]] = None,
    changes: Optional[Dict[str, Any]] = None,
    request: Optional[Request] = None,
    status: int = 1,
    error_message: Optional[str] = None,
) -> AdminLog:
    """创建审计日志"""

    # 获取操作名称
    action_name = LOG_ACTIONS.get(action, action)

    # 脱敏请求数据
    sanitized_request = sanitize_sensitive_data(request_data) if request_data else None
    sanitized_response = sanitize_sensitive_data(response_data) if response_data else None

    # 提取请求信息
    ip_address = None
    user_agent = None
    request_method = None
    request_path = None

    if request:
        ip_address = get_client_ip(request)
        user_agent = request.headers.get("user-agent", "")[:500]
        request_method = request.method
        request_path = str(request.url.path)

    log = AdminLog(
        admin_id=admin_id,
        admin_username=admin_username,
        action=action,
        action_name=action_name,
        module=module,
        target_type=target_type,
        target_id=str(target_id) if target_id else None,
        target_name=target_name,
        description=description,
        request_data=sanitized_request,
        response_data=sanitized_response,
        changes=changes,
        ip_address=ip_address,
        user_agent=user_agent,
        request_method=request_method,
        request_path=request_path,
        status=status,
        error_message=error_message,
    )

    db.add(log)
    await db.flush()

    return log


def get_client_ip(request: Request) -> str:
    """获取客户端真实IP"""
    # 尝试从X-Forwarded-For获取
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()

    # 尝试从X-Real-IP获取
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip

    # 使用直连IP
    if request.client:
        return request.client.host

    return "unknown"


def sanitize_sensitive_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """脱敏敏感数据"""
    if not data:
        return data

    sensitive_fields = {
        "password", "password_hash", "secret", "token", "api_key",
        "credit_card", "card_number", "cvv", "pin",
    }

    sanitized = {}
    for key, value in data.items():
        lower_key = key.lower()

        # 检查是否是敏感字段
        if any(field in lower_key for field in sensitive_fields):
            sanitized[key] = "***REDACTED***"
        elif isinstance(value, dict):
            sanitized[key] = sanitize_sensitive_data(value)
        elif isinstance(value, list):
            sanitized[key] = [
                sanitize_sensitive_data(item) if isinstance(item, dict) else item
                for item in value
            ]
        else:
            sanitized[key] = value

    return sanitized


def mask_email(email: str) -> str:
    """邮箱脱敏"""
    if not email or "@" not in email:
        return email

    parts = email.split("@")
    local = parts[0]

    if len(local) <= 2:
        masked_local = local[0] + "***"
    else:
        masked_local = local[0] + "***" + local[-1]

    return f"{masked_local}@{parts[1]}"


def mask_phone(phone: str) -> str:
    """手机号脱敏"""
    if not phone or len(phone) < 7:
        return phone

    return phone[:3] + "****" + phone[-4:]


def mask_name(name: str) -> str:
    """姓名脱敏"""
    if not name:
        return name

    if len(name) == 1:
        return "*"
    elif len(name) == 2:
        return name[0] + "*"
    else:
        return name[0] + "*" * (len(name) - 1)

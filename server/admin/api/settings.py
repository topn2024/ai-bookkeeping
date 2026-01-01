"""Admin system settings endpoints."""
from datetime import datetime
from typing import Optional, Dict, Any, List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin, require_superadmin
from admin.core.permissions import has_permission
from admin.core.audit import create_audit_log
from pydantic import BaseModel, Field, EmailStr


router = APIRouter(prefix="/settings", tags=["System Settings"])


# ============ Request/Response Models ============

class SystemInfoConfig(BaseModel):
    """System info configuration (SS-001)."""
    app_name: str = Field("AI智能记账", max_length=100)
    app_logo_url: Optional[str] = None
    company_name: Optional[str] = None
    support_email: Optional[EmailStr] = None
    support_phone: Optional[str] = None
    terms_url: Optional[str] = None
    privacy_url: Optional[str] = None


class RegistrationConfig(BaseModel):
    """Registration configuration (SS-002)."""
    registration_enabled: bool = True
    require_email_verification: bool = True
    require_phone_verification: bool = False
    allowed_email_domains: Optional[List[str]] = None
    invitation_only: bool = False
    max_users: Optional[int] = None


class EmailServiceConfig(BaseModel):
    """Email service configuration (SS-003)."""
    enabled: bool = False
    provider: str = Field("smtp", pattern="^(smtp|sendgrid|ses)$")
    smtp_host: Optional[str] = None
    smtp_port: Optional[int] = 587
    smtp_username: Optional[str] = None
    smtp_password: Optional[str] = None  # Will be masked in response
    smtp_use_tls: bool = True
    from_email: Optional[EmailStr] = None
    from_name: Optional[str] = None


class SMSServiceConfig(BaseModel):
    """SMS service configuration (SS-004)."""
    enabled: bool = False
    provider: str = Field("aliyun", pattern="^(aliyun|tencent|twilio)$")
    api_key: Optional[str] = None  # Will be masked
    api_secret: Optional[str] = None  # Will be masked
    sign_name: Optional[str] = None
    template_id: Optional[str] = None


class AIServiceConfig(BaseModel):
    """AI service configuration (SS-005, SS-006)."""
    provider: str = Field("qwen", pattern="^(qwen|openai|claude)$")
    api_key: Optional[str] = None  # Will be masked
    api_base_url: Optional[str] = None
    model_name: str = "qwen-turbo"
    temperature: float = Field(0.7, ge=0, le=2)
    max_tokens: int = Field(2000, ge=100, le=8000)
    timeout_seconds: int = Field(30, ge=5, le=120)


class AIQuotaConfig(BaseModel):
    """AI quota configuration (SS-007)."""
    enabled: bool = True
    daily_limit_per_user: int = Field(50, ge=1, le=1000)
    monthly_limit_per_user: int = Field(1000, ge=1, le=30000)
    premium_daily_limit: int = Field(200, ge=1, le=5000)
    premium_monthly_limit: int = Field(5000, ge=1, le=100000)


class LoginSecurityConfig(BaseModel):
    """Login security configuration (SS-008)."""
    max_login_attempts: int = Field(5, ge=3, le=20)
    lockout_duration_minutes: int = Field(15, ge=5, le=1440)
    password_min_length: int = Field(8, ge=6, le=32)
    password_require_uppercase: bool = True
    password_require_lowercase: bool = True
    password_require_number: bool = True
    password_require_special: bool = False
    session_timeout_hours: int = Field(24, ge=1, le=720)
    require_mfa_for_admins: bool = False


class IPWhitelistConfig(BaseModel):
    """IP whitelist configuration (SS-009)."""
    enabled: bool = False
    whitelist: List[str] = []  # IP addresses or CIDR ranges
    allow_internal: bool = True  # Allow 10.x, 192.168.x, etc.


class OperationConfirmConfig(BaseModel):
    """Operation confirmation configuration (SS-010)."""
    delete_user_confirm: bool = True
    delete_transaction_confirm: bool = True
    disable_user_confirm: bool = True
    export_data_confirm: bool = False
    system_settings_confirm: bool = True


# ============ In-memory settings storage (would be database in production) ============

_settings_store: Dict[str, Any] = {
    "system_info": SystemInfoConfig().dict(),
    "registration": RegistrationConfig().dict(),
    "email_service": EmailServiceConfig().dict(),
    "sms_service": SMSServiceConfig().dict(),
    "ai_service": AIServiceConfig().dict(),
    "ai_quota": AIQuotaConfig().dict(),
    "login_security": LoginSecurityConfig().dict(),
    "ip_whitelist": IPWhitelistConfig().dict(),
    "operation_confirm": OperationConfirmConfig().dict(),
}


def mask_secret(value) -> Optional[str]:
    """Mask secret values."""
    if value is None:
        return None
    # Convert to string if not already
    if not isinstance(value, str):
        return str(value)
    if not value:
        return None
    if len(value) <= 8:
        return "****"
    return value[:4] + "****" + value[-4:]


# ============ Endpoints ============

@router.get("/system-info", response_model=SystemInfoConfig)
async def get_system_info(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取系统信息配置 (SS-001)"""
    return SystemInfoConfig(**_settings_store["system_info"])


@router.put("/system-info", response_model=SystemInfoConfig)
async def update_system_info(
    request: Request,
    config: SystemInfoConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新系统信息配置 (SS-001)"""
    old_config = _settings_store["system_info"].copy()
    _settings_store["system_info"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="system_info",
        description="更新系统信息配置",
        changes={"before": old_config, "after": config.dict()},
        request=request,
    )
    await db.commit()

    return config


@router.get("/registration", response_model=RegistrationConfig)
async def get_registration_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取注册配置 (SS-002)"""
    return RegistrationConfig(**_settings_store["registration"])


@router.put("/registration", response_model=RegistrationConfig)
async def update_registration_config(
    request: Request,
    config: RegistrationConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新注册配置 (SS-002)"""
    old_config = _settings_store["registration"].copy()
    _settings_store["registration"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="registration",
        description="更新注册配置",
        changes={"before": old_config, "after": config.dict()},
        request=request,
    )
    await db.commit()

    return config


@router.get("/email-service")
async def get_email_service_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取邮件服务配置 (SS-003)"""
    config = _settings_store["email_service"].copy()
    config["smtp_password"] = mask_secret(config.get("smtp_password"))
    return config


@router.put("/email-service")
async def update_email_service_config(
    request: Request,
    config: EmailServiceConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新邮件服务配置 (SS-003)"""
    # Keep old password if not provided
    if config.smtp_password and config.smtp_password.startswith("****"):
        config.smtp_password = _settings_store["email_service"].get("smtp_password")

    _settings_store["email_service"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="email_service",
        description="更新邮件服务配置",
        request=request,
    )
    await db.commit()

    response = config.dict()
    response["smtp_password"] = mask_secret(response.get("smtp_password"))
    return response


@router.get("/sms-service")
async def get_sms_service_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取短信服务配置 (SS-004)"""
    config = _settings_store["sms_service"].copy()
    config["api_key"] = mask_secret(config.get("api_key"))
    config["api_secret"] = mask_secret(config.get("api_secret"))
    return config


@router.put("/sms-service")
async def update_sms_service_config(
    request: Request,
    config: SMSServiceConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新短信服务配置 (SS-004)"""
    old = _settings_store["sms_service"]
    if config.api_key and config.api_key.startswith("****"):
        config.api_key = old.get("api_key")
    if config.api_secret and config.api_secret.startswith("****"):
        config.api_secret = old.get("api_secret")

    _settings_store["sms_service"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="sms_service",
        description="更新短信服务配置",
        request=request,
    )
    await db.commit()

    response = config.dict()
    response["api_key"] = mask_secret(response.get("api_key"))
    response["api_secret"] = mask_secret(response.get("api_secret"))
    return response


@router.get("/ai-service")
async def get_ai_service_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取AI服务配置 (SS-005, SS-006)"""
    config = _settings_store["ai_service"].copy()
    config["api_key"] = mask_secret(config.get("api_key"))
    return config


@router.put("/ai-service")
async def update_ai_service_config(
    request: Request,
    config: AIServiceConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新AI服务配置 (SS-005, SS-006)"""
    old = _settings_store["ai_service"]
    if config.api_key and config.api_key.startswith("****"):
        config.api_key = old.get("api_key")

    _settings_store["ai_service"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="ai_service",
        description="更新AI服务配置",
        request=request,
    )
    await db.commit()

    response = config.dict()
    response["api_key"] = mask_secret(response.get("api_key"))
    return response


@router.get("/ai-quota", response_model=AIQuotaConfig)
async def get_ai_quota_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取AI调用限额配置 (SS-007)"""
    return AIQuotaConfig(**_settings_store["ai_quota"])


@router.put("/ai-quota", response_model=AIQuotaConfig)
async def update_ai_quota_config(
    request: Request,
    config: AIQuotaConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新AI调用限额配置 (SS-007)"""
    old_config = _settings_store["ai_quota"].copy()
    _settings_store["ai_quota"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="ai_quota",
        description="更新AI调用限额配置",
        changes={"before": old_config, "after": config.dict()},
        request=request,
    )
    await db.commit()

    return config


@router.get("/login-security", response_model=LoginSecurityConfig)
async def get_login_security_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取登录安全配置 (SS-008)"""
    return LoginSecurityConfig(**_settings_store["login_security"])


@router.put("/login-security", response_model=LoginSecurityConfig)
async def update_login_security_config(
    request: Request,
    config: LoginSecurityConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新登录安全配置 (SS-008)"""
    old_config = _settings_store["login_security"].copy()
    _settings_store["login_security"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="login_security",
        description="更新登录安全配置",
        changes={"before": old_config, "after": config.dict()},
        request=request,
    )
    await db.commit()

    return config


@router.get("/ip-whitelist", response_model=IPWhitelistConfig)
async def get_ip_whitelist_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取IP白名单配置 (SS-009)"""
    return IPWhitelistConfig(**_settings_store["ip_whitelist"])


@router.put("/ip-whitelist", response_model=IPWhitelistConfig)
async def update_ip_whitelist_config(
    request: Request,
    config: IPWhitelistConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新IP白名单配置 (SS-009)"""
    old_config = _settings_store["ip_whitelist"].copy()
    _settings_store["ip_whitelist"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="ip_whitelist",
        description="更新IP白名单配置",
        changes={"before": old_config, "after": config.dict()},
        request=request,
    )
    await db.commit()

    return config


@router.get("/operation-confirm", response_model=OperationConfirmConfig)
async def get_operation_confirm_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取操作确认配置 (SS-010)"""
    return OperationConfirmConfig(**_settings_store["operation_confirm"])


@router.put("/operation-confirm", response_model=OperationConfirmConfig)
async def update_operation_confirm_config(
    request: Request,
    config: OperationConfirmConfig,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新操作确认配置 (SS-010)"""
    old_config = _settings_store["operation_confirm"].copy()
    _settings_store["operation_confirm"] = config.dict()

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="operation_confirm",
        description="更新操作确认配置",
        changes={"before": old_config, "after": config.dict()},
        request=request,
    )
    await db.commit()

    return config


@router.get("/all")
async def get_all_settings(
    current_admin: AdminUser = Depends(require_superadmin),
):
    """获取所有配置（仅超级管理员）"""
    settings = {}
    for key, value in _settings_store.items():
        settings[key] = value.copy()
        # Mask sensitive fields
        if "password" in str(settings[key]):
            for k, v in settings[key].items():
                if "password" in k.lower() or "secret" in k.lower() or "key" in k.lower():
                    settings[key][k] = mask_secret(v) if v else None

    return settings


@router.get("/security")
async def get_security_settings(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("setting:view")),
):
    """获取安全配置汇总"""
    return {
        "login_security": _settings_store["login_security"],
        "ip_whitelist": _settings_store["ip_whitelist"],
        "operation_confirm": _settings_store["operation_confirm"],
    }


@router.put("/security")
async def update_security_settings(
    request: Request,
    data: Dict[str, Any],
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """更新安全配置汇总"""
    if "login_security" in data:
        _settings_store["login_security"].update(data["login_security"])
    if "ip_whitelist" in data:
        _settings_store["ip_whitelist"].update(data["ip_whitelist"])
    if "operation_confirm" in data:
        _settings_store["operation_confirm"].update(data["operation_confirm"])

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.update",
        module="setting",
        target_type="security",
        description="更新安全配置",
        request=request,
    )
    await db.commit()

    return {"message": "Security settings updated"}


@router.post("/logo")
async def upload_logo(
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """上传系统Logo"""
    # In production, this would save to MinIO/S3
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.upload_logo",
        module="setting",
        description="上传系统Logo",
        request=request,
    )
    await db.commit()

    return {"logo_url": "/static/logo.png", "message": "Logo upload not yet implemented"}


@router.post("/email-service/test")
async def test_email_service(
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """测试邮件服务"""
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.test_email",
        module="setting",
        description="测试邮件服务",
        request=request,
    )
    await db.commit()

    return {"success": False, "message": "Email service not configured"}


@router.post("/webhook/test")
async def test_webhook(
    request: Request,
    data: Dict[str, Any],
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("setting:edit")),
):
    """测试Webhook"""
    url = data.get("url")
    if not url:
        raise HTTPException(status_code=400, detail="URL is required")

    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="setting.test_webhook",
        module="setting",
        description=f"测试Webhook: {url}",
        request=request,
    )
    await db.commit()

    return {"success": False, "message": "Webhook test not yet implemented"}

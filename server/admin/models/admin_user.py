"""Admin user model."""
from datetime import datetime
from typing import Optional
from uuid import uuid4

from sqlalchemy import Column, String, DateTime, Boolean, Integer, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.core.timezone import beijing_now_naive


class AdminUser(Base):
    """管理员用户模型"""
    __tablename__ = "admin_users"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)

    # 基本信息
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    display_name = Column(String(100), nullable=True)
    avatar_url = Column(String(500), nullable=True)
    phone = Column(String(20), nullable=True)

    # 角色关联
    role_id = Column(PGUUID(as_uuid=True), ForeignKey("admin_roles.id"), nullable=False)

    # 状态
    is_active = Column(Boolean, default=True)
    is_superadmin = Column(Boolean, default=False)  # 超级管理员标识

    # MFA配置
    mfa_enabled = Column(Boolean, default=False)
    mfa_secret = Column(String(100), nullable=True)

    # 登录信息
    last_login_at = Column(DateTime, nullable=True)
    last_login_ip = Column(String(50), nullable=True)
    login_count = Column(Integer, default=0)
    failed_login_count = Column(Integer, default=0)
    locked_until = Column(DateTime, nullable=True)  # 账户锁定到期时间

    # 时间戳
    created_at = Column(DateTime, default=beijing_now_naive)
    updated_at = Column(DateTime, default=beijing_now_naive, onupdate=beijing_now_naive)
    created_by = Column(PGUUID(as_uuid=True), nullable=True)  # 创建人

    # 关系
    role = relationship("AdminRole", back_populates="users")
    logs = relationship("AdminLog", back_populates="admin_user", foreign_keys="AdminLog.admin_id")

    def __repr__(self):
        return f"<AdminUser {self.username}>"

    @property
    def is_locked(self) -> bool:
        """检查账户是否被锁定"""
        if self.locked_until is None:
            return False
        return datetime.utcnow() < self.locked_until

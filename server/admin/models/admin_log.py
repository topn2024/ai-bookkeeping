"""Admin operation log model."""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, String, DateTime, Integer, Text, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.orm import relationship

from app.core.database import Base


class AdminLog(Base):
    """管理员操作日志模型"""
    __tablename__ = "admin_logs"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)

    # 操作人
    admin_id = Column(PGUUID(as_uuid=True), ForeignKey("admin_users.id"), nullable=False, index=True)
    admin_username = Column(String(50), nullable=False)  # 冗余存储，便于查询

    # 操作信息
    action = Column(String(100), nullable=False, index=True)  # 操作类型 (如: user.disable)
    action_name = Column(String(100), nullable=False)  # 操作名称 (如: 禁用用户)
    module = Column(String(50), nullable=False, index=True)  # 模块 (如: user)

    # 操作对象
    target_type = Column(String(50), nullable=True)  # 目标类型 (如: user, transaction)
    target_id = Column(String(100), nullable=True, index=True)  # 目标ID
    target_name = Column(String(200), nullable=True)  # 目标名称/描述

    # 操作详情
    description = Column(Text, nullable=True)  # 操作描述
    request_data = Column(JSONB, nullable=True)  # 请求数据 (脱敏后)
    response_data = Column(JSONB, nullable=True)  # 响应数据 (脱敏后)
    changes = Column(JSONB, nullable=True)  # 数据变更 (before/after)

    # 请求信息
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(String(500), nullable=True)
    request_method = Column(String(10), nullable=True)
    request_path = Column(String(500), nullable=True)

    # 结果
    status = Column(Integer, default=1)  # 1=成功, 0=失败
    error_message = Column(Text, nullable=True)

    # 时间
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # 关系
    admin_user = relationship("AdminUser", back_populates="logs", foreign_keys=[admin_id])

    def __repr__(self):
        return f"<AdminLog {self.action} by {self.admin_username}>"


# 预定义操作类型
LOG_ACTIONS = {
    # 认证相关
    "auth.login": "管理员登录",
    "auth.logout": "管理员登出",
    "auth.password_change": "修改密码",
    "auth.mfa_enable": "启用MFA",
    "auth.mfa_disable": "禁用MFA",

    # 用户管理
    "user.view": "查看用户",
    "user.list": "查看用户列表",
    "user.detail": "查看用户详情",
    "user.edit": "编辑用户",
    "user.disable": "禁用用户",
    "user.enable": "启用用户",
    "user.delete": "删除用户",
    "user.reset_password": "重置用户密码",
    "user.export": "导出用户数据",

    # 交易管理
    "transaction.list": "查看交易列表",
    "transaction.detail": "查看交易详情",
    "transaction.edit": "编辑交易",
    "transaction.delete": "删除交易",
    "transaction.export": "导出交易数据",

    # 数据管理
    "data.category.create": "创建系统分类",
    "data.category.edit": "编辑系统分类",
    "data.category.delete": "删除系统分类",
    "data.backup.delete": "删除备份",

    # 系统设置
    "setting.view": "查看系统设置",
    "setting.edit": "修改系统设置",

    # 管理员管理
    "admin.create": "创建管理员",
    "admin.edit": "编辑管理员",
    "admin.delete": "删除管理员",
    "admin.role.create": "创建角色",
    "admin.role.edit": "编辑角色",
    "admin.role.delete": "删除角色",
}

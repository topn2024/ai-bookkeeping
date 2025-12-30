"""Admin role and permission models."""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, String, DateTime, Boolean, Integer, ForeignKey, Text, Table
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import relationship

from app.core.database import Base


# 角色-权限关联表
RolePermission = Table(
    'admin_role_permissions',
    Base.metadata,
    Column('role_id', PGUUID(as_uuid=True), ForeignKey('admin_roles.id', ondelete='CASCADE'), primary_key=True),
    Column('permission_id', PGUUID(as_uuid=True), ForeignKey('admin_permissions.id', ondelete='CASCADE'), primary_key=True),
)


class AdminRole(Base):
    """管理员角色模型"""
    __tablename__ = "admin_roles"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)

    # 角色信息
    name = Column(String(50), unique=True, nullable=False)  # 角色标识 (如: super_admin, operator)
    display_name = Column(String(100), nullable=False)  # 显示名称 (如: 超级管理员)
    description = Column(String(500), nullable=True)

    # 状态
    is_system = Column(Boolean, default=False)  # 是否系统内置角色
    is_active = Column(Boolean, default=True)

    # 排序
    sort_order = Column(Integer, default=0)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # 关系
    users = relationship("AdminUser", back_populates="role")
    permissions = relationship("AdminPermission", secondary=RolePermission, back_populates="roles")

    def __repr__(self):
        return f"<AdminRole {self.name}>"


class AdminPermission(Base):
    """管理员权限模型"""
    __tablename__ = "admin_permissions"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)

    # 权限信息
    code = Column(String(100), unique=True, nullable=False, index=True)  # 权限代码 (如: user:read)
    name = Column(String(100), nullable=False)  # 权限名称 (如: 查看用户)
    description = Column(String(500), nullable=True)

    # 分组
    module = Column(String(50), nullable=False)  # 所属模块 (如: user, transaction, system)

    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)

    # 关系
    roles = relationship("AdminRole", secondary=RolePermission, back_populates="permissions")

    def __repr__(self):
        return f"<AdminPermission {self.code}>"


# 预定义权限列表
PREDEFINED_PERMISSIONS = [
    # 仪表盘
    {"code": "dashboard:view", "name": "查看仪表盘", "module": "dashboard"},

    # 用户管理
    {"code": "user:list", "name": "查看用户列表", "module": "user"},
    {"code": "user:detail", "name": "查看用户详情", "module": "user"},
    {"code": "user:edit", "name": "编辑用户", "module": "user"},
    {"code": "user:disable", "name": "禁用/启用用户", "module": "user"},
    {"code": "user:delete", "name": "删除用户", "module": "user"},
    {"code": "user:export", "name": "导出用户数据", "module": "user"},

    # 交易管理
    {"code": "data:transaction:view", "name": "查看交易列表", "module": "data"},
    {"code": "data:transaction:edit", "name": "编辑交易", "module": "data"},
    {"code": "data:transaction:delete", "name": "删除交易", "module": "data"},
    {"code": "data:transaction:export", "name": "导出交易数据", "module": "data"},

    # 账本管理
    {"code": "data:book:view", "name": "查看账本列表", "module": "data"},
    {"code": "data:book:edit", "name": "编辑账本", "module": "data"},

    # 账户管理
    {"code": "data:account:view", "name": "查看账户列表", "module": "data"},
    {"code": "data:account:edit", "name": "编辑账户", "module": "data"},

    # 分类管理
    {"code": "data:category:view", "name": "查看分类列表", "module": "data"},
    {"code": "data:category:edit", "name": "编辑系统分类", "module": "data"},

    # 备份管理
    {"code": "data:backup:view", "name": "查看备份列表", "module": "data"},
    {"code": "data:backup:edit", "name": "编辑备份策略", "module": "data"},
    {"code": "data:backup:delete", "name": "删除备份", "module": "data"},

    # 数据完整性
    {"code": "data:integrity:check", "name": "数据完整性检查", "module": "data"},

    # 统计分析
    {"code": "stats:user", "name": "查看用户统计", "module": "stats"},
    {"code": "stats:transaction", "name": "查看交易统计", "module": "stats"},
    {"code": "stats:report", "name": "生成报表", "module": "stats"},
    {"code": "stats:export", "name": "导出报表", "module": "stats"},

    # 系统监控
    {"code": "monitor:view", "name": "查看系统监控", "module": "monitor"},
    {"code": "monitor:alert", "name": "管理告警", "module": "monitor"},

    # 系统设置
    {"code": "setting:view", "name": "查看系统设置", "module": "setting"},
    {"code": "setting:edit", "name": "修改系统设置", "module": "setting"},

    # 管理员管理
    {"code": "admin:list", "name": "查看管理员列表", "module": "admin"},
    {"code": "admin:create", "name": "创建管理员", "module": "admin"},
    {"code": "admin:edit", "name": "编辑管理员", "module": "admin"},
    {"code": "admin:delete", "name": "删除管理员", "module": "admin"},
    {"code": "admin:role:list", "name": "查看角色列表", "module": "admin"},
    {"code": "admin:role:edit", "name": "编辑角色", "module": "admin"},

    # 审计日志
    {"code": "log:view", "name": "查看操作日志", "module": "log"},
    {"code": "log:export", "name": "导出操作日志", "module": "log"},
]


# 预定义角色及其权限
PREDEFINED_ROLES = {
    "super_admin": {
        "display_name": "超级管理员",
        "description": "系统最高权限，可管理所有功能",
        "is_system": True,
        "permissions": ["*"],  # 所有权限
    },
    "operator": {
        "display_name": "运营管理员",
        "description": "日常运营管理，可管理用户和数据",
        "is_system": True,
        "permissions": [
            "dashboard:view",
            "user:list", "user:detail", "user:edit", "user:disable", "user:export",
            "data:transaction:view", "data:transaction:export",
            "data:book:view", "data:account:view",
            "data:category:view", "data:category:edit",
            "data:backup:view", "data:backup:delete",
            "data:integrity:check",
            "stats:user", "stats:transaction", "stats:report", "stats:export",
            "log:view",
        ],
    },
    "analyst": {
        "display_name": "数据分析员",
        "description": "只读权限，用于数据分析",
        "is_system": True,
        "permissions": [
            "dashboard:view",
            "user:list", "user:detail",
            "data:transaction:view",
            "data:book:view", "data:account:view", "data:category:view",
            "stats:user", "stats:transaction", "stats:report", "stats:export",
        ],
    },
    "customer_service": {
        "display_name": "客服专员",
        "description": "处理用户问题，查看用户和交易信息",
        "is_system": True,
        "permissions": [
            "dashboard:view",
            "user:list", "user:detail",
            "data:transaction:view",
        ],
    },
    "auditor": {
        "display_name": "审计员",
        "description": "安全审计，查看操作日志",
        "is_system": True,
        "permissions": [
            "dashboard:view",
            "log:view", "log:export",
        ],
    },
}

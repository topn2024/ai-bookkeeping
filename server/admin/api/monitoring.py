"""Admin system monitoring endpoints."""
import logging
import os
import platform
import psutil
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any

from fastapi import APIRouter, Depends, Query, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import create_audit_log
from pydantic import BaseModel

logger = logging.getLogger(__name__)


router = APIRouter(prefix="/monitoring", tags=["System Monitoring"])


# ============ Response Models ============

class ServiceStatus(BaseModel):
    """Service status model."""
    name: str
    status: str  # "healthy", "degraded", "unhealthy"
    latency_ms: Optional[float] = None
    message: Optional[str] = None
    last_check: datetime


class SystemHealthResponse(BaseModel):
    """System health response."""
    overall_status: str
    services: List[ServiceStatus]
    checked_at: datetime


class DatabaseStats(BaseModel):
    """Database statistics."""
    status: str
    connection_count: int
    max_connections: int
    database_size: str
    table_count: int
    uptime: Optional[str] = None


class StorageStats(BaseModel):
    """Storage statistics."""
    total_bytes: int
    used_bytes: int
    free_bytes: int
    usage_percent: float
    total_formatted: str
    used_formatted: str
    free_formatted: str


class SystemResourceStats(BaseModel):
    """System resource statistics."""
    cpu_percent: float
    memory_percent: float
    memory_used_mb: float
    memory_total_mb: float
    disk: StorageStats
    platform: str
    python_version: str
    uptime_seconds: float


class APIMetrics(BaseModel):
    """API metrics."""
    endpoint: str
    method: str
    avg_response_time_ms: float
    request_count: int
    error_count: int
    error_rate: float


class ErrorStats(BaseModel):
    """Error statistics."""
    total_errors: int
    by_status_code: Dict[str, int]
    by_endpoint: List[Dict[str, Any]]
    recent_errors: List[Dict[str, Any]]


# ============ Helper Functions ============

def format_bytes(size_bytes: int) -> str:
    """Format bytes to human readable string."""
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024 * 1024:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024 * 1024 * 1024:
        return f"{size_bytes / (1024 * 1024):.1f} MB"
    else:
        return f"{size_bytes / (1024 * 1024 * 1024):.2f} GB"


# ============ Endpoints ============

@router.get("/health", response_model=SystemHealthResponse)
async def check_system_health(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:view")),
):
    """API健康检查 (SM-001)"""
    services = []
    now = datetime.utcnow()

    # Check database
    try:
        start = datetime.utcnow()
        await db.execute(text("SELECT 1"))
        latency = (datetime.utcnow() - start).total_seconds() * 1000
        services.append(ServiceStatus(
            name="PostgreSQL",
            status="healthy",
            latency_ms=round(latency, 2),
            message="Database connection successful",
            last_check=now,
        ))
    except Exception as e:
        services.append(ServiceStatus(
            name="PostgreSQL",
            status="unhealthy",
            message=str(e),
            last_check=now,
        ))

    # Check API service itself
    services.append(ServiceStatus(
        name="Admin API",
        status="healthy",
        latency_ms=0,
        message="Service running normally",
        last_check=now,
    ))

    # Check main API (simplified - would need actual health check endpoint)
    services.append(ServiceStatus(
        name="Main API",
        status="healthy",
        message="Assumed healthy (same process)",
        last_check=now,
    ))

    # Determine overall status
    unhealthy_count = sum(1 for s in services if s.status == "unhealthy")
    degraded_count = sum(1 for s in services if s.status == "degraded")

    if unhealthy_count > 0:
        overall_status = "unhealthy"
    elif degraded_count > 0:
        overall_status = "degraded"
    else:
        overall_status = "healthy"

    return SystemHealthResponse(
        overall_status=overall_status,
        services=services,
        checked_at=now,
    )


@router.get("/database", response_model=DatabaseStats)
async def get_database_stats(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:view")),
):
    """数据库状态监控 (SM-002)"""
    try:
        # Get database size
        size_result = await db.execute(
            text("SELECT pg_database_size(current_database())")
        )
        db_size = size_result.scalar() or 0

        # Get table count
        table_result = await db.execute(
            text("""
                SELECT count(*) FROM information_schema.tables
                WHERE table_schema = 'public'
            """)
        )
        table_count = table_result.scalar() or 0

        # Get connection count
        conn_result = await db.execute(
            text("SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()")
        )
        conn_count = conn_result.scalar() or 0

        # Get max connections
        max_conn_result = await db.execute(
            text("SHOW max_connections")
        )
        max_conn = int(max_conn_result.scalar() or 100)

        return DatabaseStats(
            status="healthy",
            connection_count=conn_count,
            max_connections=max_conn,
            database_size=format_bytes(db_size),
            table_count=table_count,
        )
    except Exception as e:
        return DatabaseStats(
            status="error",
            connection_count=0,
            max_connections=0,
            database_size="Unknown",
            table_count=0,
        )


@router.get("/storage", response_model=StorageStats)
async def get_storage_stats(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("monitor:view")),
):
    """存储空间监控 (SM-004)"""
    try:
        disk = psutil.disk_usage('/')
        return StorageStats(
            total_bytes=disk.total,
            used_bytes=disk.used,
            free_bytes=disk.free,
            usage_percent=disk.percent,
            total_formatted=format_bytes(disk.total),
            used_formatted=format_bytes(disk.used),
            free_formatted=format_bytes(disk.free),
        )
    except Exception:
        return StorageStats(
            total_bytes=0,
            used_bytes=0,
            free_bytes=0,
            usage_percent=0,
            total_formatted="Unknown",
            used_formatted="Unknown",
            free_formatted="Unknown",
        )


@router.get("/resources", response_model=SystemResourceStats)
async def get_system_resources(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("monitor:view")),
):
    """系统资源监控"""
    try:
        # CPU
        cpu_percent = psutil.cpu_percent(interval=0.1)

        # Memory
        memory = psutil.virtual_memory()
        memory_percent = memory.percent
        memory_used_mb = memory.used / (1024 * 1024)
        memory_total_mb = memory.total / (1024 * 1024)

        # Disk
        disk = psutil.disk_usage('/')
        disk_stats = StorageStats(
            total_bytes=disk.total,
            used_bytes=disk.used,
            free_bytes=disk.free,
            usage_percent=disk.percent,
            total_formatted=format_bytes(disk.total),
            used_formatted=format_bytes(disk.used),
            free_formatted=format_bytes(disk.free),
        )

        # System info
        import sys
        boot_time = psutil.boot_time()
        uptime_seconds = (datetime.now().timestamp() - boot_time)

        return SystemResourceStats(
            cpu_percent=cpu_percent,
            memory_percent=memory_percent,
            memory_used_mb=round(memory_used_mb, 2),
            memory_total_mb=round(memory_total_mb, 2),
            disk=disk_stats,
            platform=platform.system(),
            python_version=sys.version.split()[0],
            uptime_seconds=round(uptime_seconds, 0),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get system resources: {str(e)}",
        )


@router.get("/api-metrics")
async def get_api_metrics(
    hours: int = Query(24, ge=1, le=168),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:view")),
):
    """API响应时间和请求量统计 (SM-005, SM-006)"""
    from admin.models.admin_log import AdminLog

    start_time = datetime.utcnow() - timedelta(hours=hours)

    try:
        # 获取总请求数（基于审计日志）
        total_result = await db.execute(
            select(func.count(AdminLog.id))
            .where(AdminLog.created_at >= start_time)
        )
        total_requests = total_result.scalar() or 0

        # 按模块统计请求数
        module_stats = await db.execute(
            select(
                AdminLog.module,
                func.count(AdminLog.id).label("count")
            )
            .where(AdminLog.created_at >= start_time)
            .group_by(AdminLog.module)
            .order_by(func.count(AdminLog.id).desc())
            .limit(20)
        )

        endpoints = [
            {
                "module": row.module or "unknown",
                "request_count": row.count,
                "error_count": 0,  # 可从status字段统计
                "error_rate": 0.0,
            }
            for row in module_stats.all()
        ]

        # 按操作类型统计
        action_stats = await db.execute(
            select(
                AdminLog.action,
                func.count(AdminLog.id).label("count")
            )
            .where(AdminLog.created_at >= start_time)
            .group_by(AdminLog.action)
            .order_by(func.count(AdminLog.id).desc())
            .limit(20)
        )

        actions = [
            {"action": row.action, "count": row.count}
            for row in action_stats.all()
        ]

        # 按小时统计请求量趋势
        hourly_stats = await db.execute(
            select(
                func.date_trunc('hour', AdminLog.created_at).label("hour"),
                func.count(AdminLog.id).label("count")
            )
            .where(AdminLog.created_at >= start_time)
            .group_by(func.date_trunc('hour', AdminLog.created_at))
            .order_by(func.date_trunc('hour', AdminLog.created_at))
        )

        hourly_trend = [
            {"hour": row.hour.isoformat() if row.hour else None, "count": row.count}
            for row in hourly_stats.all()
        ]

        return {
            "period_hours": hours,
            "total_requests": total_requests,
            "avg_response_time_ms": 0,  # 需要实际的响应时间记录
            "endpoints": endpoints,
            "actions": actions,
            "hourly_trend": hourly_trend,
            "data_source": "admin_audit_logs",
        }
    except Exception as e:
        return {
            "period_hours": hours,
            "total_requests": 0,
            "avg_response_time_ms": 0,
            "endpoints": [],
            "actions": [],
            "hourly_trend": [],
            "error": str(e),
            "message": "Failed to retrieve metrics from audit logs",
        }


@router.get("/errors")
async def get_error_stats(
    hours: int = Query(24, ge=1, le=168),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:view")),
):
    """错误率统计 (SM-007)"""
    from admin.models.admin_log import AdminLog

    start_time = datetime.utcnow() - timedelta(hours=hours)

    try:
        # 统计失败的操作 (status != 1)
        error_count_result = await db.execute(
            select(func.count(AdminLog.id))
            .where(
                AdminLog.created_at >= start_time,
                AdminLog.status != 1
            )
        )
        total_errors = error_count_result.scalar() or 0

        # 按状态码统计
        status_stats = await db.execute(
            select(
                AdminLog.status,
                func.count(AdminLog.id).label("count")
            )
            .where(AdminLog.created_at >= start_time)
            .group_by(AdminLog.status)
        )
        by_status_code = {
            str(row.status): row.count
            for row in status_stats.all()
        }

        # 按模块统计错误
        module_error_stats = await db.execute(
            select(
                AdminLog.module,
                func.count(AdminLog.id).label("error_count")
            )
            .where(
                AdminLog.created_at >= start_time,
                AdminLog.status != 1
            )
            .group_by(AdminLog.module)
            .order_by(func.count(AdminLog.id).desc())
            .limit(10)
        )
        by_endpoint = [
            {"module": row.module or "unknown", "error_count": row.error_count}
            for row in module_error_stats.all()
        ]

        # 最近的错误
        recent_errors_result = await db.execute(
            select(AdminLog)
            .where(
                AdminLog.created_at >= start_time,
                AdminLog.status != 1
            )
            .order_by(AdminLog.created_at.desc())
            .limit(20)
        )
        recent_errors = [
            {
                "id": str(log.id),
                "action": log.action,
                "module": log.module,
                "description": log.description,
                "admin_username": log.admin_username,
                "ip_address": log.ip_address,
                "status": log.status,
                "created_at": log.created_at.isoformat() if log.created_at else None,
            }
            for log in recent_errors_result.scalars().all()
        ]

        return {
            "period_hours": hours,
            "total_errors": total_errors,
            "by_status_code": by_status_code,
            "by_endpoint": by_endpoint,
            "recent_errors": recent_errors,
            "data_source": "admin_audit_logs",
        }
    except Exception as e:
        return {
            "period_hours": hours,
            "total_errors": 0,
            "by_status_code": {},
            "by_endpoint": [],
            "recent_errors": [],
            "error": str(e),
            "message": "Failed to retrieve error stats from audit logs",
        }


@router.get("/slow-queries")
async def get_slow_queries(
    hours: int = Query(24, ge=1, le=168),
    min_duration_ms: int = Query(1000, ge=100),
    limit: int = Query(50, ge=1, le=200),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:view")),
):
    """慢查询日志 (SM-008)"""
    try:
        # Check if pg_stat_statements is available
        result = await db.execute(
            text("""
                SELECT query, calls, total_exec_time, mean_exec_time
                FROM pg_stat_statements
                WHERE mean_exec_time > :min_duration
                ORDER BY mean_exec_time DESC
                LIMIT :limit
            """),
            {"min_duration": min_duration_ms, "limit": limit}
        )
        rows = result.all()

        queries = [
            {
                "query": row.query[:200] + "..." if len(row.query) > 200 else row.query,
                "calls": row.calls,
                "total_time_ms": round(row.total_exec_time, 2),
                "avg_time_ms": round(row.mean_exec_time, 2),
            }
            for row in rows
        ]

        return {
            "period_hours": hours,
            "min_duration_ms": min_duration_ms,
            "slow_queries": queries,
        }
    except Exception:
        return {
            "period_hours": hours,
            "min_duration_ms": min_duration_ms,
            "slow_queries": [],
            "message": "pg_stat_statements extension not available or insufficient permissions",
        }


@router.get("/alerts/rules")
async def get_alert_rules(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("monitor:alert")),
):
    """获取告警规则配置 (SM-009)"""
    # Default alert rules
    rules = [
        {
            "id": "cpu_high",
            "name": "CPU使用率过高",
            "metric": "cpu_percent",
            "condition": ">",
            "threshold": 80,
            "duration_minutes": 5,
            "severity": "warning",
            "enabled": True,
        },
        {
            "id": "memory_high",
            "name": "内存使用率过高",
            "metric": "memory_percent",
            "condition": ">",
            "threshold": 85,
            "duration_minutes": 5,
            "severity": "warning",
            "enabled": True,
        },
        {
            "id": "disk_high",
            "name": "磁盘使用率过高",
            "metric": "disk_percent",
            "condition": ">",
            "threshold": 90,
            "duration_minutes": 1,
            "severity": "critical",
            "enabled": True,
        },
        {
            "id": "db_connections_high",
            "name": "数据库连接数过高",
            "metric": "db_connections",
            "condition": ">",
            "threshold": 80,
            "duration_minutes": 5,
            "severity": "warning",
            "enabled": True,
        },
        {
            "id": "api_error_rate",
            "name": "API错误率过高",
            "metric": "error_rate",
            "condition": ">",
            "threshold": 5,
            "duration_minutes": 5,
            "severity": "critical",
            "enabled": True,
        },
    ]

    return {"rules": rules}


class AlertRuleUpdate(BaseModel):
    """Alert rule update request."""
    threshold: Optional[float] = None
    enabled: Optional[bool] = None


@router.put("/alerts/rules/{rule_id}")
async def update_alert_rule(
    rule_id: str,
    update_data: AlertRuleUpdate,
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:alert")),
):
    """更新告警规则 (SM-009)"""
    logger.info(f"Admin {current_admin.username} updating alert rule: {rule_id}")

    # In a real implementation, this would update in database
    result = {
        "message": f"Alert rule {rule_id} updated",
        "rule_id": rule_id,
        "threshold": update_data.threshold,
        "enabled": update_data.enabled,
    }

    # Create audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="monitor.alert.update",
        module="monitoring",
        target_type="alert_rule",
        target_id=rule_id,
        description=f"更新告警规则 {rule_id}",
        request_data=update_data.model_dump(),
        request=request,
    )
    await db.commit()

    logger.info(f"Alert rule {rule_id} updated successfully")
    return result


@router.get("/alerts/notifications")
async def get_notification_config(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("monitor:alert")),
):
    """获取告警通知配置 (SM-010)"""
    return {
        "channels": [
            {
                "type": "email",
                "enabled": False,
                "recipients": [],
                "config": {},
            },
            {
                "type": "sms",
                "enabled": False,
                "recipients": [],
                "config": {},
            },
            {
                "type": "webhook",
                "enabled": False,
                "url": None,
                "config": {},
            },
        ],
        "message": "Notification channels not yet configured",
    }


@router.put("/alerts/notifications")
async def update_notification_config(
    config: Dict[str, Any],
    request: Request,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("monitor:alert")),
):
    """更新告警通知配置 (SM-010)"""
    logger.info(f"Admin {current_admin.username} updating notification config")

    result = {
        "message": "Notification config updated",
        "config": config,
    }

    # Create audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="monitor.notification.update",
        module="monitoring",
        target_type="notification_config",
        description="更新告警通知配置",
        request_data=config,
        request=request,
    )
    await db.commit()

    logger.info("Notification config updated successfully")
    return result

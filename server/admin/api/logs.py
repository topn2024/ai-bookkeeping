"""Admin audit log endpoints."""
import io
from datetime import datetime, date, timedelta
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from admin.models.admin_user import AdminUser
from admin.models.admin_log import AdminLog, LOG_ACTIONS
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import create_audit_log
from pydantic import BaseModel


router = APIRouter(prefix="/logs", tags=["Admin Logs"])


class AdminLogItem(BaseModel):
    """审计日志项"""
    id: UUID
    admin_id: UUID
    admin_username: str
    action: str
    action_name: str
    module: str
    target_type: Optional[str] = None
    target_id: Optional[str] = None
    target_name: Optional[str] = None
    description: Optional[str] = None
    ip_address: Optional[str] = None
    status: int
    created_at: datetime

    class Config:
        from_attributes = True


class AdminLogListResponse(BaseModel):
    """审计日志列表响应"""
    items: List[AdminLogItem]
    total: int
    page: int
    page_size: int


class AdminLogDetail(AdminLogItem):
    """审计日志详情"""
    user_agent: Optional[str] = None
    request_method: Optional[str] = None
    request_path: Optional[str] = None
    request_data: Optional[dict] = None
    response_data: Optional[dict] = None
    changes: Optional[dict] = None
    error_message: Optional[str] = None


class LogActionListResponse(BaseModel):
    """操作类型列表"""
    actions: dict  # {action_code: action_name}


@router.get("", response_model=AdminLogListResponse)
async def list_logs(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin_id: Optional[UUID] = None,
    action: Optional[str] = None,
    module: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("log:view")),
):
    """获取审计日志列表"""
    query = select(AdminLog)

    # 筛选条件
    conditions = []

    if admin_id:
        conditions.append(AdminLog.admin_id == admin_id)

    if action:
        conditions.append(AdminLog.action == action)

    if module:
        conditions.append(AdminLog.module == module)

    if start_date:
        conditions.append(func.date(AdminLog.created_at) >= start_date)

    if end_date:
        conditions.append(func.date(AdminLog.created_at) <= end_date)

    if conditions:
        query = query.where(and_(*conditions))

    # 获取总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 排序和分页
    offset = (page - 1) * page_size
    query = query.order_by(AdminLog.created_at.desc()).offset(offset).limit(page_size)

    result = await db.execute(query)
    logs = result.scalars().all()

    return AdminLogListResponse(
        items=logs,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/actions", response_model=LogActionListResponse)
async def list_log_actions(
    current_admin: AdminUser = Depends(get_current_admin),
    _: bool = Depends(has_permission("log:view")),
):
    """获取所有操作类型"""
    return LogActionListResponse(actions=LOG_ACTIONS)


@router.get("/modules")
async def list_log_modules(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("log:view")),
):
    """获取所有模块列表"""
    result = await db.execute(
        select(AdminLog.module)
        .distinct()
        .order_by(AdminLog.module)
    )
    modules = [row[0] for row in result.all()]

    return {"modules": modules}


@router.get("/stats")
async def get_log_stats(
    days: int = Query(7, ge=1, le=30),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("log:view")),
):
    """获取日志统计"""
    start_date = date.today() - timedelta(days=days - 1)

    # 按日期统计
    daily_result = await db.execute(
        select(
            func.date(AdminLog.created_at).label("day"),
            func.count(AdminLog.id).label("count"),
        )
        .where(func.date(AdminLog.created_at) >= start_date)
        .group_by(func.date(AdminLog.created_at))
        .order_by(func.date(AdminLog.created_at))
    )
    daily_stats = {row.day: row.count for row in daily_result.all()}

    # 按模块统计
    module_result = await db.execute(
        select(
            AdminLog.module,
            func.count(AdminLog.id).label("count"),
        )
        .where(func.date(AdminLog.created_at) >= start_date)
        .group_by(AdminLog.module)
        .order_by(func.count(AdminLog.id).desc())
    )
    module_stats = {row.module: row.count for row in module_result.all()}

    # 按操作人统计
    admin_result = await db.execute(
        select(
            AdminLog.admin_username,
            func.count(AdminLog.id).label("count"),
        )
        .where(func.date(AdminLog.created_at) >= start_date)
        .group_by(AdminLog.admin_username)
        .order_by(func.count(AdminLog.id).desc())
        .limit(10)
    )
    admin_stats = {row.admin_username: row.count for row in admin_result.all()}

    # 填充每日数据
    daily_data = []
    for i in range(days):
        d = start_date + timedelta(days=i)
        daily_data.append({
            "date": d.isoformat(),
            "count": daily_stats.get(d, 0),
        })

    return {
        "daily": daily_data,
        "by_module": module_stats,
        "by_admin": admin_stats,
    }


@router.get("/{log_id}", response_model=AdminLogDetail)
async def get_log_detail(
    log_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("log:view")),
):
    """获取日志详情"""
    result = await db.execute(
        select(AdminLog).where(AdminLog.id == log_id)
    )
    log = result.scalar_one_or_none()

    if not log:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="日志不存在",
        )

    return log


# ============ Log Export (GF-007) ============

@router.get("/export")
async def export_logs(
    request: Request,
    format: str = Query("csv", pattern="^(csv|xlsx)$"),
    admin_id: Optional[UUID] = None,
    action: Optional[str] = None,
    module: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("log:export")),
):
    """导出审计日志 (GF-007)"""
    query = select(AdminLog)
    conditions = []

    if admin_id:
        conditions.append(AdminLog.admin_id == admin_id)

    if action:
        conditions.append(AdminLog.action == action)

    if module:
        conditions.append(AdminLog.module == module)

    if start_date:
        conditions.append(func.date(AdminLog.created_at) >= start_date)

    if end_date:
        conditions.append(func.date(AdminLog.created_at) <= end_date)

    if conditions:
        query = query.where(and_(*conditions))

    query = query.order_by(AdminLog.created_at.desc()).limit(10000)  # Limit to 10k records

    result = await db.execute(query)
    logs = result.scalars().all()

    # Prepare data
    rows = []
    for log in logs:
        rows.append({
            "ID": str(log.id),
            "管理员": log.admin_username,
            "操作": LOG_ACTIONS.get(log.action, log.action),
            "模块": log.module,
            "目标类型": log.target_type or "",
            "目标ID": log.target_id or "",
            "目标名称": log.target_name or "",
            "描述": log.description or "",
            "IP地址": log.ip_address or "",
            "状态": "成功" if log.status == 1 else "失败",
            "时间": log.created_at.strftime("%Y-%m-%d %H:%M:%S") if log.created_at else "",
        })

    # Generate file
    if format == "csv":
        output = io.StringIO()
        if rows:
            headers = list(rows[0].keys())
            output.write(",".join(headers) + "\n")
            for row in rows:
                values = []
                for h in headers:
                    v = str(row.get(h, ""))
                    if "," in v or '"' in v or "\n" in v:
                        v = '"' + v.replace('"', '""') + '"'
                    values.append(v)
                output.write(",".join(values) + "\n")

        content = output.getvalue().encode('utf-8-sig')
        media_type = "text/csv; charset=utf-8"
        filename = f"audit_logs_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    else:
        output = io.StringIO()
        if rows:
            headers = list(rows[0].keys())
            output.write("\t".join(headers) + "\n")
            for row in rows:
                output.write("\t".join(str(row.get(h, "")) for h in headers) + "\n")

        content = output.getvalue().encode('utf-8-sig')
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename = f"audit_logs_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

    # Audit log for export action
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="log.export",
        module="log",
        description=f"导出审计日志: {len(rows)}条记录, 格式={format}",
        request=request,
    )
    await db.commit()

    return StreamingResponse(
        io.BytesIO(content),
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

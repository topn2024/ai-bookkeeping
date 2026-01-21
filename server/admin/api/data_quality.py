"""数据质量监控API

提供数据质量检查结果的查询和管理接口。
"""
import logging
from typing import List, Optional
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func, and_, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from admin.api.deps import get_current_admin, require_permission
from admin.models.admin_user import AdminUser
from admin.models.data_quality_check import DataQualityCheck
from admin.schemas.data_quality import (
    DataQualityOverviewResponse,
    DataQualityChecksListResponse,
    DataQualityCheckResponse,
    ResolveCheckRequest,
    ResolveCheckResponse,
    TableQualityScore,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/monitoring/data-quality", tags=["Data Quality Monitoring"])


@router.get(
    "/overview",
    response_model=DataQualityOverviewResponse,
    summary="获取数据质量概览",
)
async def get_data_quality_overview(
    days: int = Query(7, ge=1, le=90, description="统计天数"),
    db: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(require_permission("monitor:data_quality:view")),
):
    """
    获取数据质量概览信息

    包括：
    - 综合质量评分
    - 按严重程度统计的问题数量
    - 各表的质量评分
    - 最近的检查记录

    权限要求：monitor:data_quality:view
    """
    try:
        cutoff_time = datetime.utcnow() - timedelta(days=days)

        # 1. 统计各严重程度的问题数量（未解决的）
        severity_query = (
            select(
                DataQualityCheck.severity,
                func.count(DataQualityCheck.id).label("count"),
            )
            .where(
                and_(
                    DataQualityCheck.check_time >= cutoff_time,
                    DataQualityCheck.status.in_(["detected", "investigating"]),
                )
            )
            .group_by(DataQualityCheck.severity)
        )
        severity_result = await db.execute(severity_query)
        severity_stats = {row[0]: row[1] for row in severity_result.fetchall()}

        recent_issues = {
            "critical": severity_stats.get("critical", 0),
            "high": severity_stats.get("high", 0),
            "medium": severity_stats.get("medium", 0),
            "low": severity_stats.get("low", 0),
        }

        # 2. 计算综合质量评分
        total_issues = sum(recent_issues.values())
        # 简单算法：每个critical扣10分，high扣5分，medium扣2分，low扣0.5分
        penalty = (
            recent_issues["critical"] * 10
            + recent_issues["high"] * 5
            + recent_issues["medium"] * 2
            + recent_issues["low"] * 0.5
        )
        overall_score = max(0, 100 - penalty)

        # 3. 统计各表的质量评分
        table_query = (
            select(
                DataQualityCheck.target_table,
                func.count(DataQualityCheck.id).label("issue_count"),
                func.sum(DataQualityCheck.total_records).label("total_records"),
            )
            .where(
                and_(
                    DataQualityCheck.check_time >= cutoff_time,
                    DataQualityCheck.status.in_(["detected", "investigating"]),
                )
            )
            .group_by(DataQualityCheck.target_table)
        )
        table_result = await db.execute(table_query)
        tables_data = table_result.fetchall()

        by_table = []
        for row in tables_data:
            table_name, issue_count, total_records = row
            # 简单算法：每个问题扣除一定比例的分数
            score = max(0, 100 - (issue_count * 5))
            by_table.append(
                TableQualityScore(
                    table_name=table_name,
                    score=round(score, 1),
                    total_records=int(total_records or 0),
                    issue_count=int(issue_count),
                )
            )

        # 按评分排序
        by_table.sort(key=lambda x: x.score)

        # 4. 获取最近的检查记录（最多10条）
        recent_checks_query = (
            select(DataQualityCheck)
            .where(DataQualityCheck.check_time >= cutoff_time)
            .order_by(desc(DataQualityCheck.check_time))
            .limit(10)
        )
        recent_checks_result = await db.execute(recent_checks_query)
        recent_checks = recent_checks_result.scalars().all()

        return DataQualityOverviewResponse(
            overall_score=round(overall_score, 1),
            recent_issues=recent_issues,
            by_table=by_table,
            recent_checks=[
                DataQualityCheckResponse.model_validate(check) for check in recent_checks
            ],
        )

    except Exception as e:
        logger.error(f"Error getting data quality overview: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取数据质量概览失败")


@router.get(
    "/checks",
    response_model=DataQualityChecksListResponse,
    summary="获取数据质量检查列表",
)
async def get_data_quality_checks(
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页大小"),
    severity: Optional[List[str]] = Query(None, description="严重程度筛选"),
    status: Optional[List[str]] = Query(None, description="状态筛选"),
    table: Optional[str] = Query(None, description="表名筛选"),
    days: int = Query(7, ge=1, le=365, description="时间范围（天）"),
    db: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(require_permission("monitor:data_quality:view")),
):
    """
    获取数据质量检查列表

    支持筛选：
    - severity: 严重程度（可多选）
    - status: 状态（可多选）
    - table: 表名
    - days: 时间范围

    权限要求：monitor:data_quality:view
    """
    try:
        cutoff_time = datetime.utcnow() - timedelta(days=days)

        # 构建查询条件
        conditions = [DataQualityCheck.check_time >= cutoff_time]

        if severity:
            conditions.append(DataQualityCheck.severity.in_(severity))

        if status:
            conditions.append(DataQualityCheck.status.in_(status))

        if table:
            conditions.append(DataQualityCheck.target_table == table)

        # 查询总数
        count_query = select(func.count(DataQualityCheck.id)).where(and_(*conditions))
        count_result = await db.execute(count_query)
        total = count_result.scalar() or 0

        # 查询列表
        offset = (page - 1) * page_size
        list_query = (
            select(DataQualityCheck)
            .where(and_(*conditions))
            .order_by(desc(DataQualityCheck.check_time))
            .offset(offset)
            .limit(page_size)
        )
        list_result = await db.execute(list_query)
        checks = list_result.scalars().all()

        return DataQualityChecksListResponse(
            total=total,
            page=page,
            page_size=page_size,
            items=[DataQualityCheckResponse.model_validate(check) for check in checks],
        )

    except Exception as e:
        logger.error(f"Error getting data quality checks: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取数据质量检查列表失败")


@router.get(
    "/checks/{check_id}",
    response_model=DataQualityCheckResponse,
    summary="获取单个检查详情",
)
async def get_data_quality_check_detail(
    check_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(require_permission("monitor:data_quality:view")),
):
    """
    获取单个数据质量检查的详细信息

    权限要求：monitor:data_quality:view
    """
    try:
        query = select(DataQualityCheck).where(DataQualityCheck.id == check_id)
        result = await db.execute(query)
        check = result.scalar_one_or_none()

        if not check:
            raise HTTPException(status_code=404, detail=f"检查记录 {check_id} 不存在")

        return DataQualityCheckResponse.model_validate(check)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting check detail {check_id}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="获取检查详情失败")


@router.post(
    "/checks/{check_id}/resolve",
    response_model=ResolveCheckResponse,
    summary="标记问题已解决",
)
async def resolve_data_quality_check(
    check_id: int,
    request: ResolveCheckRequest,
    db: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(
        require_permission("monitor:data_quality:manage")
    ),
):
    """
    标记数据质量问题为已解决

    权限要求：monitor:data_quality:manage
    """
    try:
        # 查询检查记录
        query = select(DataQualityCheck).where(DataQualityCheck.id == check_id)
        result = await db.execute(query)
        check = result.scalar_one_or_none()

        if not check:
            raise HTTPException(status_code=404, detail=f"检查记录 {check_id} 不存在")

        # 更新状态
        check.status = "fixed"
        check.resolved_at = datetime.utcnow()
        check.resolution_notes = request.resolution_notes
        check.assigned_to = request.assigned_to or current_admin.username

        await db.commit()
        await db.refresh(check)

        logger.info(
            f"Admin {current_admin.username} resolved data quality check {check_id}",
            extra={
                "admin_id": current_admin.id,
                "check_id": check_id,
                "resolution_notes": request.resolution_notes,
            },
        )

        return ResolveCheckResponse(
            success=True,
            message="问题已标记为已解决",
            check=DataQualityCheckResponse.model_validate(check),
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error resolving check {check_id}: {e}", exc_info=True)
        await db.rollback()
        raise HTTPException(status_code=500, detail="标记解决失败")


@router.post(
    "/checks/{check_id}/ignore",
    response_model=ResolveCheckResponse,
    summary="忽略问题",
)
async def ignore_data_quality_check(
    check_id: int,
    request: ResolveCheckRequest,
    db: AsyncSession = Depends(get_db),
    current_admin: AdminUser = Depends(
        require_permission("monitor:data_quality:manage")
    ),
):
    """
    忽略数据质量问题

    权限要求：monitor:data_quality:manage
    """
    try:
        # 查询检查记录
        query = select(DataQualityCheck).where(DataQualityCheck.id == check_id)
        result = await db.execute(query)
        check = result.scalar_one_or_none()

        if not check:
            raise HTTPException(status_code=404, detail=f"检查记录 {check_id} 不存在")

        # 更新状态
        check.status = "ignored"
        check.resolved_at = datetime.utcnow()
        check.resolution_notes = request.resolution_notes
        check.assigned_to = request.assigned_to or current_admin.username

        await db.commit()
        await db.refresh(check)

        logger.info(
            f"Admin {current_admin.username} ignored data quality check {check_id}",
            extra={
                "admin_id": current_admin.id,
                "check_id": check_id,
                "resolution_notes": request.resolution_notes,
            },
        )

        return ResolveCheckResponse(
            success=True,
            message="问题已忽略",
            check=DataQualityCheckResponse.model_validate(check),
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error ignoring check {check_id}: {e}", exc_info=True)
        await db.rollback()
        raise HTTPException(status_code=500, detail="忽略失败")

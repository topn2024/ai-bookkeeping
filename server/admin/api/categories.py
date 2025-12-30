"""Admin category management endpoints."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.models.category import Category
from app.models.transaction import Transaction
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import create_audit_log
from admin.schemas.data_management import (
    CategoryItem,
    CategoryListResponse,
    CategoryCreate,
    CategoryUpdate,
    CategoryUsageStats,
    CategoryUsageStatsResponse,
)


router = APIRouter(prefix="/categories", tags=["Category Management"])


CATEGORY_TYPES = {1: "支出", 2: "收入"}


@router.get("", response_model=CategoryListResponse)
async def list_categories(
    category_type: Optional[int] = Query(None, ge=1, le=2),
    is_system: Optional[bool] = None,
    keyword: Optional[str] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:category:view")),
):
    """获取分类列表 (DM-011)"""
    query = select(Category)

    conditions = []

    if category_type is not None:
        conditions.append(Category.category_type == category_type)

    if is_system is not None:
        conditions.append(Category.is_system == is_system)

    if keyword:
        conditions.append(Category.name.ilike(f"%{keyword}%"))

    if conditions:
        query = query.where(and_(*conditions))

    query = query.order_by(Category.is_system.desc(), Category.sort_order, Category.name)

    result = await db.execute(query)
    categories = result.scalars().all()

    # Build response with usage count
    items = []
    for cat in categories:
        # Get usage count
        usage_result = await db.execute(
            select(func.count(Transaction.id)).where(Transaction.category_id == cat.id)
        )
        usage_count = usage_result.scalar() or 0

        items.append(CategoryItem(
            id=cat.id,
            user_id=cat.user_id,
            parent_id=cat.parent_id,
            name=cat.name,
            icon=cat.icon,
            category_type=cat.category_type,
            sort_order=cat.sort_order,
            is_system=cat.is_system,
            usage_count=usage_count,
            created_at=cat.created_at,
        ))

    return CategoryListResponse(
        items=items,
        total=len(items),
    )


@router.get("/system", response_model=CategoryListResponse)
async def list_system_categories(
    category_type: Optional[int] = Query(None, ge=1, le=2),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:category:view")),
):
    """获取系统分类列表（管理预置分类）"""
    query = select(Category).where(Category.is_system == True)

    if category_type is not None:
        query = query.where(Category.category_type == category_type)

    query = query.order_by(Category.sort_order, Category.name)

    result = await db.execute(query)
    categories = result.scalars().all()

    items = []
    for cat in categories:
        usage_result = await db.execute(
            select(func.count(Transaction.id)).where(Transaction.category_id == cat.id)
        )
        usage_count = usage_result.scalar() or 0

        items.append(CategoryItem(
            id=cat.id,
            user_id=None,
            parent_id=cat.parent_id,
            name=cat.name,
            icon=cat.icon,
            category_type=cat.category_type,
            sort_order=cat.sort_order,
            is_system=True,
            usage_count=usage_count,
            created_at=cat.created_at,
        ))

    return CategoryListResponse(
        items=items,
        total=len(items),
    )


@router.post("/system", response_model=CategoryItem)
async def create_system_category(
    request: Request,
    category_data: CategoryCreate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:category:edit")),
):
    """添加系统分类 (DM-012)"""
    # Check if name already exists for system categories
    existing = await db.execute(
        select(Category).where(
            and_(
                Category.name == category_data.name,
                Category.is_system == True,
                Category.category_type == category_data.category_type,
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="同类型的系统分类名称已存在",
        )

    # Check parent if provided
    if category_data.parent_id:
        parent_result = await db.execute(
            select(Category).where(
                and_(
                    Category.id == category_data.parent_id,
                    Category.is_system == True,
                )
            )
        )
        if not parent_result.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="父分类不存在或不是系统分类",
            )

    # Create category
    new_category = Category(
        user_id=None,  # System category has no user
        parent_id=category_data.parent_id,
        name=category_data.name,
        icon=category_data.icon,
        category_type=category_data.category_type,
        sort_order=category_data.sort_order,
        is_system=True,
    )

    db.add(new_category)

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="category.create",
        module="category",
        target_type="category",
        target_id=str(new_category.id),
        target_name=new_category.name,
        description=f"创建系统分类: {new_category.name}",
        request=request,
    )

    await db.commit()
    await db.refresh(new_category)

    return CategoryItem(
        id=new_category.id,
        user_id=None,
        parent_id=new_category.parent_id,
        name=new_category.name,
        icon=new_category.icon,
        category_type=new_category.category_type,
        sort_order=new_category.sort_order,
        is_system=True,
        usage_count=0,
        created_at=new_category.created_at,
    )


@router.put("/system/{category_id}", response_model=CategoryItem)
async def update_system_category(
    request: Request,
    category_id: UUID,
    category_data: CategoryUpdate,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:category:edit")),
):
    """编辑系统分类 (DM-013)"""
    result = await db.execute(
        select(Category).where(
            and_(
                Category.id == category_id,
                Category.is_system == True,
            )
        )
    )
    category = result.scalar_one_or_none()

    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="系统分类不存在",
        )

    changes = {}

    if category_data.name is not None and category_data.name != category.name:
        # Check for duplicate name
        existing = await db.execute(
            select(Category).where(
                and_(
                    Category.name == category_data.name,
                    Category.is_system == True,
                    Category.category_type == category.category_type,
                    Category.id != category_id,
                )
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="同类型的系统分类名称已存在",
            )
        changes["name"] = {"before": category.name, "after": category_data.name}
        category.name = category_data.name

    if category_data.icon is not None:
        changes["icon"] = {"before": category.icon, "after": category_data.icon}
        category.icon = category_data.icon

    if category_data.sort_order is not None:
        changes["sort_order"] = {"before": category.sort_order, "after": category_data.sort_order}
        category.sort_order = category_data.sort_order

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="category.edit",
        module="category",
        target_type="category",
        target_id=str(category_id),
        target_name=category.name,
        description=f"编辑系统分类: {category.name}",
        changes=changes,
        request=request,
    )

    await db.commit()
    await db.refresh(category)

    # Get usage count
    usage_result = await db.execute(
        select(func.count(Transaction.id)).where(Transaction.category_id == category.id)
    )
    usage_count = usage_result.scalar() or 0

    return CategoryItem(
        id=category.id,
        user_id=None,
        parent_id=category.parent_id,
        name=category.name,
        icon=category.icon,
        category_type=category.category_type,
        sort_order=category.sort_order,
        is_system=True,
        usage_count=usage_count,
        created_at=category.created_at,
    )


@router.delete("/system/{category_id}")
async def delete_system_category(
    request: Request,
    category_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:category:edit")),
):
    """删除系统分类"""
    result = await db.execute(
        select(Category).where(
            and_(
                Category.id == category_id,
                Category.is_system == True,
            )
        )
    )
    category = result.scalar_one_or_none()

    if not category:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="系统分类不存在",
        )

    # Check if category is in use
    usage_result = await db.execute(
        select(func.count(Transaction.id)).where(Transaction.category_id == category_id)
    )
    usage_count = usage_result.scalar() or 0

    if usage_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"该分类有 {usage_count} 条交易记录使用，无法删除",
        )

    # Check for child categories
    child_result = await db.execute(
        select(func.count(Category.id)).where(Category.parent_id == category_id)
    )
    child_count = child_result.scalar() or 0

    if child_count > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"该分类有 {child_count} 个子分类，无法删除",
        )

    category_name = category.name

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="category.delete",
        module="category",
        target_type="category",
        target_id=str(category_id),
        target_name=category_name,
        description=f"删除系统分类: {category_name}",
        request=request,
    )

    await db.delete(category)
    await db.commit()

    return {"message": "分类已删除"}


@router.get("/usage-stats", response_model=CategoryUsageStatsResponse)
async def get_category_usage_stats(
    category_type: Optional[int] = Query(None, ge=1, le=2),
    limit: int = Query(20, ge=1, le=100),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:category:view")),
):
    """获取分类使用统计 (DM-014)"""
    # Build query for category usage
    query = select(
        Category.id,
        Category.name,
        Category.category_type,
        Category.is_system,
        func.count(Transaction.id).label("transaction_count"),
        func.coalesce(func.sum(Transaction.amount), 0).label("total_amount"),
        func.count(func.distinct(Transaction.user_id)).label("user_count"),
    ).outerjoin(
        Transaction, Category.id == Transaction.category_id
    ).group_by(
        Category.id, Category.name, Category.category_type, Category.is_system
    ).order_by(
        func.count(Transaction.id).desc()
    )

    if category_type is not None:
        query = query.where(Category.category_type == category_type)

    query = query.limit(limit)

    result = await db.execute(query)
    rows = result.all()

    items = [
        CategoryUsageStats(
            category_id=row.id,
            category_name=row.name,
            category_type=row.category_type,
            is_system=row.is_system,
            transaction_count=row.transaction_count,
            total_amount=Decimal(str(row.total_amount)),
            user_count=row.user_count,
        )
        for row in rows
    ]

    # Get total categories
    total_result = await db.execute(select(func.count(Category.id)))
    total = total_result.scalar() or 0

    return CategoryUsageStatsResponse(
        items=items,
        total_categories=total,
    )

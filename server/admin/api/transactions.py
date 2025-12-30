"""Admin transaction management endpoints."""
import io
from datetime import datetime, date, timedelta
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, Query, HTTPException, status, Request
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, case
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from admin.core.audit import create_audit_log
from app.models.transaction import Transaction
from app.models.user import User
from app.models.book import Book
from app.models.account import Account
from app.models.category import Category
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import mask_email
from admin.schemas.data_management import (
    TransactionItem,
    TransactionListResponse,
    TransactionDetail,
    TransactionStatsResponse,
    AbnormalTransactionItem,
    AbnormalTransactionListResponse,
)


router = APIRouter(prefix="/transactions", tags=["Transaction Management"])


TRANSACTION_TYPES = {1: "支出", 2: "收入", 3: "转账"}
SOURCE_TYPES = {0: "手动", 1: "图片识别", 2: "语音识别", 3: "邮件导入"}


@router.get("", response_model=TransactionListResponse)
async def list_transactions(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: Optional[UUID] = None,
    transaction_type: Optional[int] = Query(None, ge=1, le=3),
    min_amount: Optional[Decimal] = None,
    max_amount: Optional[Decimal] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    source: Optional[int] = Query(None, ge=0, le=3),
    keyword: Optional[str] = None,
    sort_by: str = Query("created_at", pattern="^(created_at|amount|transaction_date)$"),
    sort_order: str = Query("desc", pattern="^(asc|desc)$"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:transaction:view")),
):
    """获取全局交易列表 (DM-001, DM-002)"""
    query = select(Transaction)

    # Build conditions
    conditions = []

    if user_id:
        conditions.append(Transaction.user_id == user_id)

    if transaction_type:
        conditions.append(Transaction.transaction_type == transaction_type)

    if min_amount is not None:
        conditions.append(Transaction.amount >= min_amount)

    if max_amount is not None:
        conditions.append(Transaction.amount <= max_amount)

    if start_date:
        conditions.append(Transaction.transaction_date >= start_date)

    if end_date:
        conditions.append(Transaction.transaction_date <= end_date)

    if source is not None:
        conditions.append(Transaction.source == source)

    if keyword:
        conditions.append(
            or_(
                Transaction.note.ilike(f"%{keyword}%"),
                Transaction.tags.contains([keyword]),
            )
        )

    if conditions:
        query = query.where(and_(*conditions))

    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Sorting
    sort_column = getattr(Transaction, sort_by)
    if sort_order == "desc":
        sort_column = sort_column.desc()
    query = query.order_by(sort_column)

    # Pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    transactions = result.scalars().all()

    # Build response with related data
    items = []
    for tx in transactions:
        # Get related data
        user_result = await db.execute(select(User.email).where(User.id == tx.user_id))
        user_email = user_result.scalar()

        book_result = await db.execute(select(Book.name).where(Book.id == tx.book_id))
        book_name = book_result.scalar()

        account_result = await db.execute(select(Account.name).where(Account.id == tx.account_id))
        account_name = account_result.scalar()

        category_result = await db.execute(select(Category.name).where(Category.id == tx.category_id))
        category_name = category_result.scalar()

        items.append(TransactionItem(
            id=tx.id,
            user_id=tx.user_id,
            user_email=mask_email(user_email) if user_email else None,
            book_id=tx.book_id,
            book_name=book_name,
            account_id=tx.account_id,
            account_name=account_name,
            category_id=tx.category_id,
            category_name=category_name,
            transaction_type=tx.transaction_type,
            amount=tx.amount,
            fee=tx.fee,
            transaction_date=tx.transaction_date,
            note=tx.note,
            tags=tx.tags,
            source=tx.source,
            is_reimbursable=tx.is_reimbursable,
            is_reimbursed=tx.is_reimbursed,
            created_at=tx.created_at,
        ))

    return TransactionListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/stats", response_model=TransactionStatsResponse)
async def get_transaction_stats(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    user_id: Optional[UUID] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:transaction:view")),
):
    """获取交易统计 (DM-006)"""
    if not start_date:
        start_date = date.today() - timedelta(days=30)
    if not end_date:
        end_date = date.today()

    conditions = [
        Transaction.transaction_date >= start_date,
        Transaction.transaction_date <= end_date,
    ]
    if user_id:
        conditions.append(Transaction.user_id == user_id)

    # Total counts and amounts
    stats_query = select(
        func.count(Transaction.id).label("total_count"),
        func.coalesce(
            func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)),
            0
        ).label("total_expense"),
        func.coalesce(
            func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)),
            0
        ).label("total_income"),
        func.coalesce(
            func.sum(case((Transaction.transaction_type == 3, Transaction.amount), else_=0)),
            0
        ).label("total_transfer"),
    ).where(and_(*conditions))

    result = await db.execute(stats_query)
    stats = result.one()

    total_count = stats.total_count or 0
    total_expense = Decimal(str(stats.total_expense or 0))
    total_income = Decimal(str(stats.total_income or 0))
    total_transfer = Decimal(str(stats.total_transfer or 0))

    # Calculate averages
    expense_count_result = await db.execute(
        select(func.count(Transaction.id))
        .where(and_(*conditions, Transaction.transaction_type == 1))
    )
    expense_count = expense_count_result.scalar() or 1

    income_count_result = await db.execute(
        select(func.count(Transaction.id))
        .where(and_(*conditions, Transaction.transaction_type == 2))
    )
    income_count = income_count_result.scalar() or 1

    avg_expense = total_expense / expense_count if expense_count > 0 else Decimal("0")
    avg_income = total_income / income_count if income_count > 0 else Decimal("0")

    # By date
    daily_query = select(
        Transaction.transaction_date,
        func.sum(case((Transaction.transaction_type == 1, Transaction.amount), else_=0)).label("expense"),
        func.sum(case((Transaction.transaction_type == 2, Transaction.amount), else_=0)).label("income"),
        func.count(Transaction.id).label("count"),
    ).where(and_(*conditions)).group_by(Transaction.transaction_date).order_by(Transaction.transaction_date)

    daily_result = await db.execute(daily_query)
    by_date = [
        {
            "date": row.transaction_date.isoformat(),
            "expense": float(row.expense or 0),
            "income": float(row.income or 0),
            "count": row.count,
        }
        for row in daily_result.all()
    ]

    # By category (top 10)
    category_query = select(
        Transaction.category_id,
        Category.name.label("category_name"),
        func.sum(Transaction.amount).label("amount"),
        func.count(Transaction.id).label("count"),
    ).join(Category, Transaction.category_id == Category.id).where(
        and_(*conditions)
    ).group_by(Transaction.category_id, Category.name).order_by(
        func.sum(Transaction.amount).desc()
    ).limit(10)

    category_result = await db.execute(category_query)
    by_category = [
        {
            "category_id": str(row.category_id),
            "category_name": row.category_name,
            "amount": float(row.amount or 0),
            "count": row.count,
        }
        for row in category_result.all()
    ]

    # By source
    source_query = select(
        Transaction.source,
        func.count(Transaction.id).label("count"),
    ).where(and_(*conditions)).group_by(Transaction.source)

    source_result = await db.execute(source_query)
    by_source = {
        SOURCE_TYPES.get(row.source, "unknown"): row.count
        for row in source_result.all()
    }

    return TransactionStatsResponse(
        total_count=total_count,
        total_expense=total_expense,
        total_income=total_income,
        total_transfer=total_transfer,
        avg_expense=avg_expense.quantize(Decimal("0.01")),
        avg_income=avg_income.quantize(Decimal("0.01")),
        by_date=by_date,
        by_category=by_category,
        by_source=by_source,
    )


@router.get("/abnormal", response_model=AbnormalTransactionListResponse)
async def list_abnormal_transactions(
    days: int = Query(7, ge=1, le=30),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:transaction:view")),
):
    """获取异常交易列表 (DM-004)"""
    start_date = date.today() - timedelta(days=days)

    # Get average transaction amount per user
    avg_query = select(
        Transaction.user_id,
        func.avg(Transaction.amount).label("avg_amount"),
        func.stddev(Transaction.amount).label("stddev_amount"),
    ).where(
        Transaction.transaction_date >= start_date
    ).group_by(Transaction.user_id)

    avg_result = await db.execute(avg_query)
    user_stats = {row.user_id: (row.avg_amount or 0, row.stddev_amount or 0) for row in avg_result.all()}

    # Find abnormal transactions (amount > avg + 3*stddev)
    abnormal_items = []

    for user_id, (avg_amount, stddev_amount) in user_stats.items():
        if stddev_amount == 0:
            continue

        threshold = float(avg_amount) + 3 * float(stddev_amount)

        high_amount_query = select(Transaction).where(
            and_(
                Transaction.user_id == user_id,
                Transaction.amount > threshold,
                Transaction.transaction_date >= start_date,
            )
        ).limit(10)

        result = await db.execute(high_amount_query)
        transactions = result.scalars().all()

        for tx in transactions:
            user_result = await db.execute(select(User.email).where(User.id == tx.user_id))
            user_email = user_result.scalar()

            abnormal_items.append(AbnormalTransactionItem(
                id=tx.id,
                user_id=tx.user_id,
                user_email=mask_email(user_email) if user_email else None,
                amount=tx.amount,
                transaction_type=tx.transaction_type,
                transaction_date=tx.transaction_date,
                abnormal_type="high_amount",
                abnormal_reason=f"金额 {tx.amount} 超过用户平均值 ({avg_amount:.2f}) 的3个标准差",
                created_at=tx.created_at,
            ))

    # Sort by amount descending
    abnormal_items.sort(key=lambda x: x.amount, reverse=True)

    return AbnormalTransactionListResponse(
        items=abnormal_items[:50],  # Limit to 50 items
        total=len(abnormal_items),
    )


@router.get("/{transaction_id}", response_model=TransactionDetail)
async def get_transaction_detail(
    transaction_id: UUID,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:transaction:view")),
):
    """获取交易详情 (DM-003)"""
    result = await db.execute(
        select(Transaction).where(Transaction.id == transaction_id)
    )
    tx = result.scalar_one_or_none()

    if not tx:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="交易不存在",
        )

    # Get related data
    user_result = await db.execute(select(User.email).where(User.id == tx.user_id))
    user_email = user_result.scalar()

    book_result = await db.execute(select(Book.name).where(Book.id == tx.book_id))
    book_name = book_result.scalar()

    account_result = await db.execute(select(Account.name).where(Account.id == tx.account_id))
    account_name = account_result.scalar()

    category_result = await db.execute(select(Category.name).where(Category.id == tx.category_id))
    category_name = category_result.scalar()

    target_account_name = None
    if tx.target_account_id:
        target_result = await db.execute(select(Account.name).where(Account.id == tx.target_account_id))
        target_account_name = target_result.scalar()

    return TransactionDetail(
        id=tx.id,
        user_id=tx.user_id,
        user_email=mask_email(user_email) if user_email else None,
        book_id=tx.book_id,
        book_name=book_name,
        account_id=tx.account_id,
        account_name=account_name,
        target_account_id=tx.target_account_id,
        target_account_name=target_account_name,
        category_id=tx.category_id,
        category_name=category_name,
        transaction_type=tx.transaction_type,
        amount=tx.amount,
        fee=tx.fee,
        transaction_date=tx.transaction_date,
        note=tx.note,
        tags=tx.tags,
        images=tx.images,
        location=tx.location,
        source=tx.source,
        is_reimbursable=tx.is_reimbursable,
        is_reimbursed=tx.is_reimbursed,
        is_exclude_stats=tx.is_exclude_stats,
        ai_confidence=tx.ai_confidence,
        source_file_url=tx.source_file_url,
        source_file_type=tx.source_file_type,
        created_at=tx.created_at,
        updated_at=tx.updated_at,
    )


# ============ Transaction Export (DM-005) ============

@router.get("/export")
async def export_transactions(
    request: Request,
    format: str = Query("csv", pattern="^(csv|xlsx)$"),
    user_id: Optional[UUID] = None,
    transaction_type: Optional[int] = Query(None, ge=1, le=3),
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    include_details: bool = Query(False, description="是否包含详细信息（账户、分类名称等）"),
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:transaction:export")),
):
    """导出交易数据 (DM-005)"""
    # Build query
    query = select(Transaction)
    conditions = []

    if user_id:
        conditions.append(Transaction.user_id == user_id)

    if transaction_type:
        conditions.append(Transaction.transaction_type == transaction_type)

    if start_date:
        conditions.append(Transaction.transaction_date >= start_date)

    if end_date:
        conditions.append(Transaction.transaction_date <= end_date)

    if conditions:
        query = query.where(and_(*conditions))

    query = query.order_by(Transaction.transaction_date.desc())

    result = await db.execute(query)
    transactions = result.scalars().all()

    # Prepare data
    rows = []
    for tx in transactions:
        row = {
            "ID": str(tx.id),
            "用户ID": str(tx.user_id),
            "类型": TRANSACTION_TYPES.get(tx.transaction_type, "未知"),
            "金额": float(tx.amount),
            "手续费": float(tx.fee) if tx.fee else 0,
            "交易日期": tx.transaction_date.isoformat() if tx.transaction_date else "",
            "备注": tx.note or "",
            "来源": SOURCE_TYPES.get(tx.source, "未知"),
            "是否可报销": "是" if tx.is_reimbursable else "否",
            "是否已报销": "是" if tx.is_reimbursed else "否",
            "创建时间": tx.created_at.strftime("%Y-%m-%d %H:%M:%S") if tx.created_at else "",
        }

        if include_details:
            # Get related names
            user_result = await db.execute(select(User.email).where(User.id == tx.user_id))
            user_email = user_result.scalar()
            row["用户邮箱(脱敏)"] = mask_email(user_email) if user_email else ""

            book_result = await db.execute(select(Book.name).where(Book.id == tx.book_id))
            row["账本"] = book_result.scalar() or ""

            account_result = await db.execute(select(Account.name).where(Account.id == tx.account_id))
            row["账户"] = account_result.scalar() or ""

            category_result = await db.execute(select(Category.name).where(Category.id == tx.category_id))
            row["分类"] = category_result.scalar() or ""

            row["标签"] = ",".join(tx.tags) if tx.tags else ""
            row["位置"] = tx.location or ""
            row["AI置信度"] = tx.ai_confidence if tx.ai_confidence else ""

        rows.append(row)

    # Generate file
    if format == "csv":
        output = io.StringIO()
        if rows:
            headers = list(rows[0].keys())
            output.write(",".join(headers) + "\n")
            for row in rows:
                # Escape commas and quotes in values
                values = []
                for h in headers:
                    v = str(row.get(h, ""))
                    if "," in v or '"' in v or "\n" in v:
                        v = '"' + v.replace('"', '""') + '"'
                    values.append(v)
                output.write(",".join(values) + "\n")

        content = output.getvalue().encode('utf-8-sig')
        media_type = "text/csv; charset=utf-8"
        filename = f"transactions_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    else:
        # For xlsx, use tab-separated format
        output = io.StringIO()
        if rows:
            headers = list(rows[0].keys())
            output.write("\t".join(headers) + "\n")
            for row in rows:
                output.write("\t".join(str(row.get(h, "")) for h in headers) + "\n")

        content = output.getvalue().encode('utf-8-sig')
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename = f"transactions_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"

    # Audit log
    await create_audit_log(
        db=db,
        admin_id=current_admin.id,
        admin_username=current_admin.username,
        action="transaction.export",
        module="data",
        description=f"导出交易数据: {len(rows)}条记录, 格式={format}",
        request=request,
    )
    await db.commit()

    return StreamingResponse(
        io.BytesIO(content),
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )

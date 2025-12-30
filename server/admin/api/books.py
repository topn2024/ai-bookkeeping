"""Admin book and account management endpoints."""
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.core.database import get_db
from app.models.book import Book, BookMember
from app.models.account import Account
from app.models.transaction import Transaction
from app.models.user import User
from admin.models.admin_user import AdminUser
from admin.api.deps import get_current_admin
from admin.core.permissions import has_permission
from admin.core.audit import mask_email
from admin.schemas.data_management import (
    BookItem,
    BookListResponse,
    AccountItem,
    AccountListResponse,
    AccountTypeStatsResponse,
)


router = APIRouter(prefix="/data", tags=["Data Management - Books & Accounts"])


BOOK_TYPES = {0: "普通账本", 1: "家庭账本", 2: "生意账本"}
ACCOUNT_TYPES = {1: "现金", 2: "储蓄卡", 3: "信用卡", 4: "支付宝", 5: "微信"}


# ============ Book/Ledger Management ============

@router.get("/books", response_model=BookListResponse)
async def list_books(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: Optional[UUID] = None,
    book_type: Optional[int] = Query(None, ge=0, le=2),
    keyword: Optional[str] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:book:view")),
):
    """获取账本列表 (DM-007)"""
    query = select(Book)

    conditions = []

    if user_id:
        conditions.append(Book.user_id == user_id)

    if book_type is not None:
        conditions.append(Book.book_type == book_type)

    if keyword:
        conditions.append(Book.name.ilike(f"%{keyword}%"))

    if conditions:
        query = query.where(and_(*conditions))

    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Pagination
    offset = (page - 1) * page_size
    query = query.order_by(Book.created_at.desc()).offset(offset).limit(page_size)

    result = await db.execute(query)
    books = result.scalars().all()

    # Build response
    items = []
    for book in books:
        # Get user email
        user_result = await db.execute(select(User.email).where(User.id == book.user_id))
        user_email = user_result.scalar()

        # Get transaction count
        tx_count_result = await db.execute(
            select(func.count(Transaction.id)).where(Transaction.book_id == book.id)
        )
        tx_count = tx_count_result.scalar() or 0

        # Get member count
        member_count_result = await db.execute(
            select(func.count(BookMember.id)).where(BookMember.book_id == book.id)
        )
        member_count = member_count_result.scalar() or 0

        items.append(BookItem(
            id=book.id,
            user_id=book.user_id,
            user_email=mask_email(user_email) if user_email else None,
            name=book.name,
            icon=book.icon,
            book_type=book.book_type,
            is_default=book.is_default,
            transaction_count=tx_count,
            member_count=member_count,
            created_at=book.created_at,
        ))

    return BookListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/books/stats")
async def get_book_stats(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:book:view")),
):
    """获取账本统计"""
    # By type
    type_query = select(
        Book.book_type,
        func.count(Book.id).label("count"),
    ).group_by(Book.book_type)

    type_result = await db.execute(type_query)
    by_type = [
        {
            "type": row.book_type,
            "type_name": BOOK_TYPES.get(row.book_type, "未知"),
            "count": row.count,
        }
        for row in type_result.all()
    ]

    # Total
    total_result = await db.execute(select(func.count(Book.id)))
    total = total_result.scalar() or 0

    # Shared books (with members)
    shared_result = await db.execute(
        select(func.count(func.distinct(BookMember.book_id)))
    )
    shared_count = shared_result.scalar() or 0

    return {
        "total_books": total,
        "shared_books": shared_count,
        "by_type": by_type,
    }


# ============ Account Management ============

@router.get("/accounts", response_model=AccountListResponse)
async def list_accounts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user_id: Optional[UUID] = None,
    account_type: Optional[int] = Query(None, ge=1, le=5),
    is_active: Optional[bool] = None,
    keyword: Optional[str] = None,
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:account:view")),
):
    """获取账户列表 (DM-008)"""
    query = select(Account)

    conditions = []

    if user_id:
        conditions.append(Account.user_id == user_id)

    if account_type is not None:
        conditions.append(Account.account_type == account_type)

    if is_active is not None:
        conditions.append(Account.is_active == is_active)

    if keyword:
        conditions.append(Account.name.ilike(f"%{keyword}%"))

    if conditions:
        query = query.where(and_(*conditions))

    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # Pagination
    offset = (page - 1) * page_size
    query = query.order_by(Account.created_at.desc()).offset(offset).limit(page_size)

    result = await db.execute(query)
    accounts = result.scalars().all()

    # Build response
    items = []
    for account in accounts:
        # Get user email
        user_result = await db.execute(select(User.email).where(User.id == account.user_id))
        user_email = user_result.scalar()

        # Get transaction count
        tx_count_result = await db.execute(
            select(func.count(Transaction.id)).where(Transaction.account_id == account.id)
        )
        tx_count = tx_count_result.scalar() or 0

        items.append(AccountItem(
            id=account.id,
            user_id=account.user_id,
            user_email=mask_email(user_email) if user_email else None,
            name=account.name,
            account_type=account.account_type,
            icon=account.icon,
            balance=account.balance,
            credit_limit=account.credit_limit,
            is_default=account.is_default,
            is_active=account.is_active,
            transaction_count=tx_count,
            created_at=account.created_at,
        ))

    return AccountListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/accounts/stats", response_model=AccountTypeStatsResponse)
async def get_account_type_stats(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:account:view")),
):
    """获取账户类型统计 (DM-009)"""
    # By type
    type_query = select(
        Account.account_type,
        func.count(Account.id).label("count"),
        func.sum(Account.balance).label("total_balance"),
    ).where(Account.is_active == True).group_by(Account.account_type)

    type_result = await db.execute(type_query)
    by_type = [
        {
            "type": row.account_type,
            "type_name": ACCOUNT_TYPES.get(row.account_type, "未知"),
            "count": row.count,
            "total_balance": float(row.total_balance or 0),
        }
        for row in type_result.all()
    ]

    # Totals
    total_result = await db.execute(
        select(
            func.count(Account.id).label("count"),
            func.sum(Account.balance).label("balance"),
        ).where(Account.is_active == True)
    )
    totals = total_result.one()

    return AccountTypeStatsResponse(
        by_type=by_type,
        total_accounts=totals.count or 0,
        total_balance=Decimal(str(totals.balance or 0)),
    )


@router.get("/integrity-check")
async def check_data_integrity(
    current_admin: AdminUser = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db),
    _: bool = Depends(has_permission("data:integrity:check")),
):
    """数据完整性检查 (DM-010)"""
    issues = []

    # 1. Check for orphan transactions (missing user)
    orphan_tx_result = await db.execute(
        select(func.count(Transaction.id))
        .outerjoin(User, Transaction.user_id == User.id)
        .where(User.id == None)
    )
    orphan_tx_count = orphan_tx_result.scalar() or 0
    if orphan_tx_count > 0:
        issues.append({
            "type": "orphan_transactions",
            "severity": "high",
            "count": orphan_tx_count,
            "description": f"发现 {orphan_tx_count} 条孤立交易记录（用户不存在）",
        })

    # 2. Check for transactions with missing categories
    missing_cat_result = await db.execute(
        select(func.count(Transaction.id))
        .outerjoin(Category, Transaction.category_id == Category.id)
        .where(Category.id == None)
    )
    missing_cat_count = missing_cat_result.scalar() or 0
    if missing_cat_count > 0:
        issues.append({
            "type": "missing_category",
            "severity": "medium",
            "count": missing_cat_count,
            "description": f"发现 {missing_cat_count} 条交易记录缺少分类",
        })

    # 3. Check for transactions with missing accounts
    missing_acc_result = await db.execute(
        select(func.count(Transaction.id))
        .outerjoin(Account, Transaction.account_id == Account.id)
        .where(Account.id == None)
    )
    missing_acc_count = missing_acc_result.scalar() or 0
    if missing_acc_count > 0:
        issues.append({
            "type": "missing_account",
            "severity": "high",
            "count": missing_acc_count,
            "description": f"发现 {missing_acc_count} 条交易记录缺少账户",
        })

    # 4. Check for negative balances (excluding credit cards)
    negative_balance_result = await db.execute(
        select(func.count(Account.id))
        .where(and_(
            Account.balance < 0,
            Account.account_type != 3,  # Not credit card
            Account.is_active == True,
        ))
    )
    negative_count = negative_balance_result.scalar() or 0
    if negative_count > 0:
        issues.append({
            "type": "negative_balance",
            "severity": "low",
            "count": negative_count,
            "description": f"发现 {negative_count} 个非信用卡账户余额为负",
        })

    # 5. Check for users without any books
    users_no_books_result = await db.execute(
        select(func.count(User.id))
        .outerjoin(Book, User.id == Book.user_id)
        .where(Book.id == None)
    )
    users_no_books = users_no_books_result.scalar() or 0
    if users_no_books > 0:
        issues.append({
            "type": "users_no_books",
            "severity": "low",
            "count": users_no_books,
            "description": f"发现 {users_no_books} 个用户没有账本",
        })

    return {
        "status": "healthy" if len(issues) == 0 else "issues_found",
        "total_issues": len(issues),
        "issues": issues,
        "checked_at": datetime.utcnow().isoformat(),
    }

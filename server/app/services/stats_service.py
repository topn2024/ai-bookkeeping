"""统计计算服务.

消除 budgets.py 和 expense_targets.py 中重复的支出计算代码。

使用方式:
```python
from app.services.stats_service import stats_service

spent = await stats_service.calculate_monthly_spent(
    db, user_id, book_id, 2024, 12
)
```
"""

from datetime import date
from decimal import Decimal
from typing import Optional, List
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_

from app.models.transaction import Transaction


class StatsService:
    """统计服务 - 提供统一的统计计算方法."""

    # 交易类型常量
    EXPENSE = 1
    INCOME = 2
    TRANSFER = 3

    async def calculate_period_spent(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        start_date: date,
        end_date: date,
        category_id: Optional[UUID] = None,
        transaction_type: int = 1,  # 默认为支出
        exclude_stats: bool = False,
        account_id: Optional[UUID] = None,
    ) -> Decimal:
        """计算指定时间段内的支出/收入总额.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            start_date: 开始日期（包含）
            end_date: 结束日期（不包含）
            category_id: 分类ID（可选）
            transaction_type: 交易类型（1:支出, 2:收入, 3:转账）
            exclude_stats: 是否只统计 is_exclude_stats=True 的记录
            account_id: 账户ID（可选）

        Returns:
            总金额（Decimal）
        """
        conditions = [
            Transaction.user_id == user_id,
            Transaction.book_id == book_id,
            Transaction.transaction_type == transaction_type,
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date < end_date,
        ]

        if not exclude_stats:
            conditions.append(Transaction.is_exclude_stats == False)

        if category_id:
            conditions.append(Transaction.category_id == category_id)

        if account_id:
            conditions.append(Transaction.account_id == account_id)

        query = select(
            func.coalesce(func.sum(Transaction.amount), Decimal(0))
        ).where(and_(*conditions))

        result = await db.execute(query)
        return result.scalar() or Decimal(0)

    async def calculate_monthly_spent(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        year: int,
        month: int,
        category_id: Optional[UUID] = None,
        transaction_type: int = 1,
    ) -> Decimal:
        """计算月度支出/收入.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            year: 年份
            month: 月份
            category_id: 分类ID（可选）
            transaction_type: 交易类型

        Returns:
            总金额
        """
        start_date = date(year, month, 1)
        end_date = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)

        return await self.calculate_period_spent(
            db,
            user_id,
            book_id,
            start_date,
            end_date,
            category_id=category_id,
            transaction_type=transaction_type,
        )

    async def calculate_yearly_spent(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        year: int,
        category_id: Optional[UUID] = None,
        transaction_type: int = 1,
    ) -> Decimal:
        """计算年度支出/收入.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            year: 年份
            category_id: 分类ID（可选）
            transaction_type: 交易类型

        Returns:
            总金额
        """
        start_date = date(year, 1, 1)
        end_date = date(year + 1, 1, 1)

        return await self.calculate_period_spent(
            db,
            user_id,
            book_id,
            start_date,
            end_date,
            category_id=category_id,
            transaction_type=transaction_type,
        )

    async def calculate_budget_spent(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        category_id: Optional[UUID],
        year: int,
        month: Optional[int] = None,
    ) -> Decimal:
        """计算预算消耗（兼容旧接口）.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            category_id: 分类ID（可选）
            year: 年份
            month: 月份（可选，为空则计算全年）

        Returns:
            已使用金额
        """
        if month:
            return await self.calculate_monthly_spent(
                db, user_id, book_id, year, month, category_id
            )
        else:
            return await self.calculate_yearly_spent(
                db, user_id, book_id, year, category_id
            )

    async def calculate_category_stats(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        start_date: date,
        end_date: date,
        transaction_type: int = 1,
    ) -> dict[UUID, Decimal]:
        """按分类统计金额.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            start_date: 开始日期
            end_date: 结束日期
            transaction_type: 交易类型

        Returns:
            分类ID到金额的映射
        """
        query = (
            select(
                Transaction.category_id,
                func.coalesce(func.sum(Transaction.amount), Decimal(0)).label("total"),
            )
            .where(
                and_(
                    Transaction.user_id == user_id,
                    Transaction.book_id == book_id,
                    Transaction.transaction_type == transaction_type,
                    Transaction.transaction_date >= start_date,
                    Transaction.transaction_date < end_date,
                    Transaction.is_exclude_stats == False,
                )
            )
            .group_by(Transaction.category_id)
        )

        result = await db.execute(query)
        rows = result.all()

        return {row.category_id: row.total for row in rows if row.category_id}

    async def calculate_daily_stats(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        start_date: date,
        end_date: date,
        transaction_type: int = 1,
    ) -> dict[date, Decimal]:
        """按日统计金额.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            start_date: 开始日期
            end_date: 结束日期
            transaction_type: 交易类型

        Returns:
            日期到金额的映射
        """
        query = (
            select(
                Transaction.transaction_date,
                func.coalesce(func.sum(Transaction.amount), Decimal(0)).label("total"),
            )
            .where(
                and_(
                    Transaction.user_id == user_id,
                    Transaction.book_id == book_id,
                    Transaction.transaction_type == transaction_type,
                    Transaction.transaction_date >= start_date,
                    Transaction.transaction_date < end_date,
                    Transaction.is_exclude_stats == False,
                )
            )
            .group_by(Transaction.transaction_date)
            .order_by(Transaction.transaction_date)
        )

        result = await db.execute(query)
        rows = result.all()

        return {row.transaction_date: row.total for row in rows}

    async def calculate_account_stats(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        start_date: date,
        end_date: date,
        transaction_type: int = 1,
    ) -> dict[UUID, Decimal]:
        """按账户统计金额.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            start_date: 开始日期
            end_date: 结束日期
            transaction_type: 交易类型

        Returns:
            账户ID到金额的映射
        """
        query = (
            select(
                Transaction.account_id,
                func.coalesce(func.sum(Transaction.amount), Decimal(0)).label("total"),
            )
            .where(
                and_(
                    Transaction.user_id == user_id,
                    Transaction.book_id == book_id,
                    Transaction.transaction_type == transaction_type,
                    Transaction.transaction_date >= start_date,
                    Transaction.transaction_date < end_date,
                    Transaction.is_exclude_stats == False,
                )
            )
            .group_by(Transaction.account_id)
        )

        result = await db.execute(query)
        rows = result.all()

        return {row.account_id: row.total for row in rows}

    async def calculate_reimbursement_stats(
        self,
        db: AsyncSession,
        user_id: UUID,
        book_id: UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
    ) -> dict:
        """计算报销统计.

        Args:
            db: 数据库会话
            user_id: 用户ID
            book_id: 账本ID
            start_date: 开始日期（可选）
            end_date: 结束日期（可选）

        Returns:
            报销统计数据
        """
        conditions = [
            Transaction.user_id == user_id,
            Transaction.book_id == book_id,
            Transaction.transaction_type == self.EXPENSE,
            Transaction.is_reimbursable == True,
        ]

        if start_date:
            conditions.append(Transaction.transaction_date >= start_date)
        if end_date:
            conditions.append(Transaction.transaction_date < end_date)

        # 可报销总额
        query = select(
            func.coalesce(func.sum(Transaction.amount), Decimal(0))
        ).where(and_(*conditions))
        result = await db.execute(query)
        total_reimbursable = result.scalar() or Decimal(0)

        # 已报销金额
        reimbursed_conditions = conditions + [Transaction.is_reimbursed == True]
        query = select(
            func.coalesce(func.sum(Transaction.amount), Decimal(0))
        ).where(and_(*reimbursed_conditions))
        result = await db.execute(query)
        total_reimbursed = result.scalar() or Decimal(0)

        return {
            "total_reimbursable": total_reimbursable,
            "total_reimbursed": total_reimbursed,
            "pending": total_reimbursable - total_reimbursed,
        }


# 单例实例
stats_service = StatsService()

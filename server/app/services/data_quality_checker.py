"""数据质量检查服务

提供自动化的数据质量检查功能，包括：
- 空值检查
- 范围检查
- 一致性检查
"""
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
from sqlalchemy import select, func, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from admin.models.data_quality_check import DataQualityCheck

logger = logging.getLogger(__name__)


class DataQualityChecker:
    """数据质量检查器"""

    def __init__(self, db: AsyncSession):
        self.db = db

    # ====================空值检查====================

    async def check_null_values(
        self,
        table_name: str,
        column_name: str,
        model_class: Any,
    ) -> Optional[DataQualityCheck]:
        """
        检查指定表和字段的空值情况

        Args:
            table_name: 表名
            column_name: 字段名
            model_class: SQLAlchemy模型类

        Returns:
            如果发现问题，返回DataQualityCheck对象；否则返回None
        """
        try:
            # 获取指定字段
            column = getattr(model_class, column_name, None)
            if column is None:
                logger.error(f"Column {column_name} not found in {table_name}")
                return None

            # 统计总记录数
            total_query = select(func.count()).select_from(model_class)
            total_result = await self.db.execute(total_query)
            total_records = total_result.scalar() or 0

            if total_records == 0:
                logger.info(f"Table {table_name} is empty, skipping null check")
                return None

            # 统计空值记录数
            null_query = select(func.count()).select_from(model_class).where(column.is_(None))
            null_result = await self.db.execute(null_query)
            null_count = null_result.scalar() or 0

            # 计算空值比例
            null_percentage = (null_count / total_records) * 100 if total_records > 0 else 0

            # 判断严重程度
            if null_percentage == 0:
                return None  # 无问题

            if null_percentage >= 10:
                severity = "critical"
            elif null_percentage >= 5:
                severity = "high"
            elif null_percentage >= 1:
                severity = "medium"
            else:
                severity = "low"

            # 获取样本ID（最多10条）
            sample_query = (
                select(model_class.id)
                .where(column.is_(None))
                .limit(10)
            )
            sample_result = await self.db.execute(sample_query)
            sample_ids = [str(row[0]) for row in sample_result.fetchall()]

            # 创建检查记录
            check = DataQualityCheck(
                check_time=datetime.utcnow(),
                check_type="null_check",
                target_table=table_name,
                target_column=column_name,
                severity=severity,
                total_records=total_records,
                affected_records=null_count,
                issue_details={
                    "null_count": null_count,
                    "null_percentage": round(null_percentage, 2),
                    "sample_ids": sample_ids,
                },
                status="detected",
            )

            logger.warning(
                f"Null check: {table_name}.{column_name} has {null_count} null values "
                f"({null_percentage:.2f}%), severity: {severity}"
            )

            return check

        except Exception as e:
            logger.error(f"Error checking null values for {table_name}.{column_name}: {e}")
            return None

    # ====================范围检查====================

    async def check_value_range(
        self,
        table_name: str,
        column_name: str,
        model_class: Any,
        min_value: Optional[float] = None,
        max_value: Optional[float] = None,
    ) -> Optional[DataQualityCheck]:
        """
        检查数值字段是否在合理范围内

        Args:
            table_name: 表名
            column_name: 字段名
            model_class: SQLAlchemy模型类
            min_value: 最小值（None表示不检查下限）
            max_value: 最大值（None表示不检查上限）

        Returns:
            如果发现问题，返回DataQualityCheck对象；否则返回None
        """
        try:
            column = getattr(model_class, column_name, None)
            if column is None:
                logger.error(f"Column {column_name} not found in {table_name}")
                return None

            # 统计总记录数（排除NULL）
            total_query = (
                select(func.count())
                .select_from(model_class)
                .where(column.isnot(None))
            )
            total_result = await self.db.execute(total_query)
            total_records = total_result.scalar() or 0

            if total_records == 0:
                return None

            # 构建范围检查条件
            conditions = []
            if min_value is not None:
                conditions.append(column < min_value)
            if max_value is not None:
                conditions.append(column > max_value)

            if not conditions:
                return None  # 没有范围限制

            # 统计范围外的记录数
            out_of_range_query = (
                select(func.count())
                .select_from(model_class)
                .where(or_(*conditions))
            )
            out_of_range_result = await self.db.execute(out_of_range_query)
            out_of_range_count = out_of_range_result.scalar() or 0

            if out_of_range_count == 0:
                return None  # 无问题

            # 计算异常比例
            out_of_range_percentage = (out_of_range_count / total_records) * 100

            # 判断严重程度
            if out_of_range_count >= 100:
                severity = "high"
            elif out_of_range_count >= 10:
                severity = "medium"
            else:
                severity = "low"

            # 获取样本
            sample_query = (
                select(model_class.id, column)
                .where(or_(*conditions))
                .limit(10)
            )
            sample_result = await self.db.execute(sample_query)
            samples = [
                {"id": str(row[0]), "value": float(row[1])}
                for row in sample_result.fetchall()
            ]

            # 创建检查记录
            check = DataQualityCheck(
                check_time=datetime.utcnow(),
                check_type="range_check",
                target_table=table_name,
                target_column=column_name,
                severity=severity,
                total_records=total_records,
                affected_records=out_of_range_count,
                issue_details={
                    "out_of_range_count": out_of_range_count,
                    "out_of_range_percentage": round(out_of_range_percentage, 2),
                    "min_value": min_value,
                    "max_value": max_value,
                    "samples": samples,
                },
                status="detected",
            )

            logger.warning(
                f"Range check: {table_name}.{column_name} has {out_of_range_count} out-of-range values, "
                f"severity: {severity}"
            )

            return check

        except Exception as e:
            logger.error(f"Error checking value range for {table_name}.{column_name}: {e}")
            return None

    # ====================一致性检查====================

    async def check_balance_consistency(
        self,
        user_id: str,
        account_model: Any,
        transaction_model: Any,
    ) -> Optional[DataQualityCheck]:
        """
        检查账户余额与交易记录的一致性

        Args:
            user_id: 用户ID
            account_model: Account模型类
            transaction_model: Transaction模型类

        Returns:
            如果发现不一致，返回DataQualityCheck对象；否则返回None
        """
        try:
            # 查询所有账户
            accounts_query = select(account_model).where(account_model.user_id == user_id)
            accounts_result = await self.db.execute(accounts_query)
            accounts = accounts_result.scalars().all()

            inconsistent_accounts = []

            for account in accounts:
                # 查询该账户的所有交易记录
                transactions_query = select(transaction_model).where(
                    transaction_model.account_id == account.id
                )
                transactions_result = await self.db.execute(transactions_query)
                transactions = transactions_result.scalars().all()

                # 计算交易总额
                calculated_balance = 0.0
                for tx in transactions:
                    if tx.type == "income":
                        calculated_balance += float(tx.amount)
                    elif tx.type == "expense":
                        calculated_balance -= float(tx.amount)

                # 对比账户余额
                account_balance = float(account.balance)
                difference = abs(account_balance - calculated_balance)

                # 如果差异超过0.01（考虑浮点数精度），认为不一致
                if difference > 0.01:
                    inconsistent_accounts.append({
                        "account_id": str(account.id),
                        "account_name": account.name,
                        "recorded_balance": account_balance,
                        "calculated_balance": round(calculated_balance, 2),
                        "difference": round(difference, 2),
                    })

            if not inconsistent_accounts:
                return None  # 无问题

            # 判断严重程度
            if len(inconsistent_accounts) >= 10:
                severity = "critical"
            elif len(inconsistent_accounts) >= 5:
                severity = "high"
            else:
                severity = "medium"

            # 创建检查记录
            check = DataQualityCheck(
                check_time=datetime.utcnow(),
                check_type="consistency_check",
                target_table="accounts",
                target_column="balance",
                severity=severity,
                total_records=len(accounts),
                affected_records=len(inconsistent_accounts),
                issue_details={
                    "user_id": user_id,
                    "inconsistent_accounts": inconsistent_accounts[:10],  # 最多10条样本
                },
                status="detected",
            )

            logger.warning(
                f"Consistency check: found {len(inconsistent_accounts)} inconsistent accounts "
                f"for user {user_id}, severity: {severity}"
            )

            return check

        except Exception as e:
            logger.error(f"Error checking balance consistency for user {user_id}: {e}")
            return None

    # ====================批量检查====================

    async def run_all_checks(self) -> List[DataQualityCheck]:
        """
        运行所有数据质量检查

        Returns:
            检查结果列表（仅包含发现问题的检查）
        """
        checks = []

        # TODO: 这里应该根据配置文件定义要检查的表和字段
        # 示例：检查transactions表的amount字段
        # from app.models.transaction import Transaction
        # check = await self.check_null_values("transactions", "amount", Transaction)
        # if check:
        #     checks.append(check)

        logger.info(f"Completed all data quality checks, found {len(checks)} issues")
        return checks

    async def save_check_results(self, checks: List[DataQualityCheck]) -> None:
        """
        保存检查结果到数据库

        Args:
            checks: 检查结果列表
        """
        try:
            for check in checks:
                self.db.add(check)
            await self.db.commit()
            logger.info(f"Saved {len(checks)} check results to database")
        except Exception as e:
            logger.error(f"Error saving check results: {e}")
            await self.db.rollback()
            raise

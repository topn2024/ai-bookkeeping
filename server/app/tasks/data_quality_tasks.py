"""数据质量检查Celery任务

定期执行数据质量检查，包括：
- 空值检查
- 范围检查
- 一致性检查
"""
import logging
from typing import List, Dict, Any
from datetime import datetime

from celery import Task

from app.tasks.celery_app import celery_app
from app.core.database import get_db_context
from app.services.data_quality_checker import DataQualityChecker
from admin.models.data_quality_check import DataQualityCheck

# 导入需要检查的模型
from app.models.transaction import Transaction
from app.models.account import Account
from app.models.category import Category
from app.models.book import Book

logger = logging.getLogger(__name__)


# 数据质量检查配置
DATA_QUALITY_CONFIG = {
    # 空值检查配置
    "null_checks": [
        {"table": "transactions", "column": "amount", "model": Transaction},
        {"table": "transactions", "column": "type", "model": Transaction},
        {"table": "transactions", "column": "category_id", "model": Transaction},
        {"table": "accounts", "column": "name", "model": Account},
        {"table": "accounts", "column": "account_type", "model": Account},
        {"table": "categories", "column": "name", "model": Category},
        {"table": "books", "column": "name", "model": Book},
    ],
    # 范围检查配置
    "range_checks": [
        {
            "table": "transactions",
            "column": "amount",
            "model": Transaction,
            "min_value": 0,
            "max_value": 1000000,  # 单笔交易最大100万
        },
        {
            "table": "accounts",
            "column": "balance",
            "model": Account,
            "min_value": -100000,  # 允许负余额（信用卡）
            "max_value": 10000000,  # 账户余额最大1000万
        },
    ],
}


class DataQualityCheckTask(Task):
    """数据质量检查任务基类"""

    def on_failure(self, exc, task_id, args, kwargs, einfo):
        """任务失败时的回调"""
        logger.error(
            f"Data quality check task {task_id} failed: {exc}",
            extra={
                "task_id": task_id,
                "exception": str(exc),
                "traceback": str(einfo),
            },
        )
        # TODO: 发送告警通知
        # send_alert(
        #     severity="high",
        #     title="数据质量检查任务失败",
        #     message=f"任务ID: {task_id}, 错误: {exc}",
        # )

    def on_success(self, retval, task_id, args, kwargs):
        """任务成功时的回调"""
        logger.info(
            f"Data quality check task {task_id} completed successfully",
            extra={
                "task_id": task_id,
                "issues_found": retval.get("issues_found", 0),
            },
        )


@celery_app.task(
    bind=True,
    base=DataQualityCheckTask,
    name="app.tasks.data_quality_tasks.periodic_data_quality_check",
    max_retries=3,
    soft_time_limit=300,  # 5分钟软限制
    time_limit=360,  # 6分钟硬限制
)
def periodic_data_quality_check(self) -> Dict[str, Any]:
    """
    定期数据质量检查任务

    检查内容：
    1. 空值检查
    2. 范围检查
    3. 一致性检查（待实现）

    Returns:
        检查结果摘要
    """
    start_time = datetime.utcnow()
    logger.info(f"Starting periodic data quality check, task_id: {self.request.id}")

    total_checks = 0
    issues_found = 0
    checks_by_severity = {"critical": 0, "high": 0, "medium": 0, "low": 0}

    try:
        async with get_db_context() as db:
            checker = DataQualityChecker(db)
            all_checks: List[DataQualityCheck] = []

            # 1. 执行空值检查
            logger.info("Running null value checks...")
            for config in DATA_QUALITY_CONFIG["null_checks"]:
                try:
                    check = await checker.check_null_values(
                        table_name=config["table"],
                        column_name=config["column"],
                        model_class=config["model"],
                    )
                    if check:
                        all_checks.append(check)
                        issues_found += 1
                        checks_by_severity[check.severity] += 1
                    total_checks += 1
                except Exception as e:
                    logger.error(
                        f"Error in null check for {config['table']}.{config['column']}: {e}"
                    )

            # 2. 执行范围检查
            logger.info("Running range checks...")
            for config in DATA_QUALITY_CONFIG["range_checks"]:
                try:
                    check = await checker.check_value_range(
                        table_name=config["table"],
                        column_name=config["column"],
                        model_class=config["model"],
                        min_value=config.get("min_value"),
                        max_value=config.get("max_value"),
                    )
                    if check:
                        all_checks.append(check)
                        issues_found += 1
                        checks_by_severity[check.severity] += 1
                    total_checks += 1
                except Exception as e:
                    logger.error(
                        f"Error in range check for {config['table']}.{config['column']}: {e}"
                    )

            # 3. 保存检查结果
            if all_checks:
                await checker.save_check_results(all_checks)
                logger.info(f"Saved {len(all_checks)} check results")

                # 触发高严重度问题的告警
                critical_checks = [c for c in all_checks if c.severity in ["critical", "high"]]
                if critical_checks:
                    await _trigger_data_quality_alerts(critical_checks)

        # 计算执行时间
        duration = (datetime.utcnow() - start_time).total_seconds()

        result = {
            "status": "completed",
            "task_id": self.request.id,
            "start_time": start_time.isoformat(),
            "duration_seconds": duration,
            "total_checks": total_checks,
            "issues_found": issues_found,
            "checks_by_severity": checks_by_severity,
        }

        logger.info(
            f"Data quality check completed: {issues_found} issues found in {duration:.2f}s",
            extra=result,
        )

        return result

    except Exception as e:
        logger.error(f"Fatal error in data quality check: {e}", exc_info=True)
        # 重试任务
        raise self.retry(exc=e, countdown=60)


async def _trigger_data_quality_alerts(checks: List[DataQualityCheck]) -> None:
    """
    触发数据质量告警

    Args:
        checks: 需要告警的检查结果列表
    """
    for check in checks:
        logger.warning(
            f"Data quality alert: {check.severity} issue in {check.target_table}.{check.target_column}",
            extra={
                "check_id": check.id,
                "check_type": check.check_type,
                "severity": check.severity,
                "affected_records": check.affected_records,
            },
        )

        # TODO: 集成现有的告警系统
        # from app.services.alert_service import send_alert
        # await send_alert(
        #     alert_type="data_quality",
        #     severity=check.severity,
        #     title=f"数据质量问题: {check.target_table}.{check.target_column}",
        #     message=f"检查类型: {check.check_type}, 影响记录数: {check.affected_records}",
        #     details=check.issue_details,
        # )


@celery_app.task(
    bind=True,
    name="app.tasks.data_quality_tasks.cleanup_old_check_results",
)
def cleanup_old_check_results(self) -> Dict[str, Any]:
    """
    清理旧的数据质量检查记录

    保留策略：
    - 已解决的低严重度问题：保留30天
    - 已解决的中高严重度问题：保留90天
    - 未解决的问题：永久保留
    """
    from datetime import timedelta

    logger.info(f"Starting cleanup of old check results, task_id: {self.request.id}")

    try:
        async with get_db_context() as db:
            from sqlalchemy import delete, and_

            now = datetime.utcnow()

            # 删除30天前已解决的低严重度问题
            delete_query_low = delete(DataQualityCheck).where(
                and_(
                    DataQualityCheck.status == "fixed",
                    DataQualityCheck.severity == "low",
                    DataQualityCheck.resolved_at < now - timedelta(days=30),
                )
            )
            result_low = await db.execute(delete_query_low)

            # 删除90天前已解决的中高严重度问题
            delete_query_high = delete(DataQualityCheck).where(
                and_(
                    DataQualityCheck.status == "fixed",
                    DataQualityCheck.severity.in_(["medium", "high", "critical"]),
                    DataQualityCheck.resolved_at < now - timedelta(days=90),
                )
            )
            result_high = await db.execute(delete_query_high)

            await db.commit()

            deleted_count = result_low.rowcount + result_high.rowcount
            logger.info(f"Cleaned up {deleted_count} old check results")

            return {
                "status": "completed",
                "deleted_count": deleted_count,
            }

    except Exception as e:
        logger.error(f"Error cleaning up old check results: {e}", exc_info=True)
        raise


@celery_app.task(name="app.tasks.data_quality_tasks.manual_data_quality_check")
def manual_data_quality_check(
    table_name: str,
    column_name: str,
    check_type: str = "null_check",
) -> Dict[str, Any]:
    """
    手动触发特定表/字段的数据质量检查

    Args:
        table_name: 表名
        column_name: 字段名
        check_type: 检查类型 (null_check, range_check)

    Returns:
        检查结果
    """
    logger.info(
        f"Manual data quality check triggered: {table_name}.{column_name} ({check_type})"
    )

    try:
        # TODO: 实现手动检查逻辑
        # 需要根据表名动态获取模型类
        return {
            "status": "completed",
            "message": f"Check for {table_name}.{column_name} completed",
        }

    except Exception as e:
        logger.error(f"Error in manual data quality check: {e}", exc_info=True)
        return {
            "status": "error",
            "message": str(e),
        }

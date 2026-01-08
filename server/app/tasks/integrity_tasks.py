"""Data integrity verification tasks.

Background tasks for:
- Periodic full system integrity verification
- User-level integrity checks
- Orphaned records detection
- Cache cleanup

Reference: Design Document Chapter 33.4 - Data Integrity Guarantee

Usage:
    # Trigger manual check
    from app.tasks.integrity_tasks import user_integrity_check
    user_integrity_check.delay(user_id="user-uuid")

    # Check task status
    result = user_integrity_check.AsyncResult(task_id)
    print(result.status, result.result)
"""
import asyncio
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from celery import shared_task

from app.tasks.celery_app import celery_app

logger = logging.getLogger(__name__)


def run_async(coro):
    """Helper to run async code in sync Celery task."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


async def _get_db_session():
    """Get database session for background tasks."""
    from app.core.database import async_session_maker
    async with async_session_maker() as session:
        yield session


async def _run_integrity_check(user_id: Optional[str] = None) -> Dict[str, Any]:
    """Run integrity check with database session."""
    from app.core.database import async_session_maker
    from app.services.data_integrity_service import data_integrity

    async with async_session_maker() as db:
        user_uuid = UUID(user_id) if user_id else None
        report = await data_integrity.run_full_check(db, user_uuid)

        return {
            "started_at": report.started_at.isoformat(),
            "completed_at": report.completed_at.isoformat() if report.completed_at else None,
            "duration_ms": report.total_duration_ms,
            "checks_run": report.checks_run,
            "checks_passed": report.checks_passed,
            "checks_failed": report.checks_failed,
            "total_issues": report.total_issues,
            "reports": [
                {
                    "check_name": r.check_name,
                    "status": r.status.value,
                    "total_checked": r.total_checked,
                    "issues_found": r.issues_found,
                    "duration_ms": r.duration_ms,
                }
                for r in report.reports
            ],
        }


@celery_app.task(
    bind=True,
    name="app.tasks.integrity_tasks.periodic_integrity_check",
    max_retries=2,
    default_retry_delay=300,
)
def periodic_integrity_check(self) -> Dict[str, Any]:
    """Run full system integrity check.

    Scheduled to run daily at 2 AM.
    Checks all users' data for integrity issues.

    Returns:
        Dict with check results summary
    """
    logger.info("Starting periodic integrity check")
    start_time = datetime.utcnow()

    try:
        result = run_async(_run_integrity_check(user_id=None))

        logger.info(
            f"Periodic integrity check completed: "
            f"{result['checks_passed']}/{result['checks_run']} passed, "
            f"{result['total_issues']} issues found"
        )

        # Log issues if any
        if result["total_issues"] > 0:
            logger.warning(
                f"Integrity issues found: {result['total_issues']} total. "
                f"Review the reports for details."
            )

        return {
            "task": "periodic_integrity_check",
            "started_at": start_time.isoformat(),
            "completed_at": datetime.utcnow().isoformat(),
            "result": result,
        }

    except Exception as e:
        logger.error(f"Periodic integrity check failed: {e}")
        raise self.retry(exc=e)


@celery_app.task(
    bind=True,
    name="app.tasks.integrity_tasks.user_integrity_check",
    max_retries=3,
    default_retry_delay=60,
)
def user_integrity_check(self, user_id: str) -> Dict[str, Any]:
    """Run integrity check for a specific user.

    Can be triggered on-demand for specific users.

    Args:
        user_id: UUID of user to check

    Returns:
        Dict with check results for the user
    """
    logger.info(f"Starting integrity check for user: {user_id}")
    start_time = datetime.utcnow()

    try:
        result = run_async(_run_integrity_check(user_id=user_id))

        logger.info(
            f"User integrity check completed for {user_id}: "
            f"{result['checks_passed']}/{result['checks_run']} passed"
        )

        return {
            "task": "user_integrity_check",
            "user_id": user_id,
            "started_at": start_time.isoformat(),
            "completed_at": datetime.utcnow().isoformat(),
            "result": result,
        }

    except Exception as e:
        logger.error(f"User integrity check failed for {user_id}: {e}")
        raise self.retry(exc=e)


async def _check_orphaned_records() -> Dict[str, Any]:
    """Check for orphaned records in database."""
    from app.core.database import async_session_maker
    from app.services.data_integrity_service import data_integrity

    async with async_session_maker() as db:
        report = await data_integrity.verify_no_orphaned_records(db)

        return {
            "check_name": report.check_name,
            "status": report.status.value,
            "checked_at": report.checked_at.isoformat(),
            "duration_ms": report.duration_ms,
            "total_checked": report.total_checked,
            "issues_found": report.issues_found,
            "issues": [
                {
                    "entity_type": issue.entity_type,
                    "entity_id": issue.entity_id,
                    "issue_type": issue.issue_type,
                    "description": issue.description,
                }
                for issue in report.issues
            ],
        }


@celery_app.task(
    bind=True,
    name="app.tasks.integrity_tasks.check_orphaned_records",
    max_retries=2,
    default_retry_delay=300,
)
def check_orphaned_records(self) -> Dict[str, Any]:
    """Check for orphaned records in the database.

    Scheduled to run weekly on Sunday at 3 AM.
    Detects transactions referencing deleted accounts/books.

    Returns:
        Dict with orphaned records check results
    """
    logger.info("Starting orphaned records check")
    start_time = datetime.utcnow()

    try:
        result = run_async(_check_orphaned_records())

        if result["issues_found"] > 0:
            logger.warning(
                f"Found {result['issues_found']} orphaned records. "
                f"Manual review recommended."
            )
        else:
            logger.info("No orphaned records found")

        return {
            "task": "check_orphaned_records",
            "started_at": start_time.isoformat(),
            "completed_at": datetime.utcnow().isoformat(),
            "result": result,
        }

    except Exception as e:
        logger.error(f"Orphaned records check failed: {e}")
        raise self.retry(exc=e)


async def _cleanup_cache() -> Dict[str, Any]:
    """Cleanup expired cache entries and delayed tasks."""
    from app.services.cache_consistency_service import cache_service

    stats_before = cache_service.get_stats_summary()

    # Cancel any pending delayed delete tasks that are stuck
    pending_count = len(cache_service._delayed_tasks)
    for key, task in list(cache_service._delayed_tasks.items()):
        if task.done():
            del cache_service._delayed_tasks[key]

    cleaned_count = pending_count - len(cache_service._delayed_tasks)

    stats_after = cache_service.get_stats_summary()

    return {
        "stats_before": stats_before,
        "stats_after": stats_after,
        "cleaned_delayed_tasks": cleaned_count,
    }


@celery_app.task(
    bind=True,
    name="app.tasks.integrity_tasks.cleanup_expired_cache",
    max_retries=1,
    default_retry_delay=60,
)
def cleanup_expired_cache(self) -> Dict[str, Any]:
    """Cleanup expired cache entries.

    Scheduled to run hourly.
    Cleans up any stuck delayed delete tasks.

    Returns:
        Dict with cleanup results
    """
    logger.info("Starting cache cleanup")
    start_time = datetime.utcnow()

    try:
        result = run_async(_cleanup_cache())

        logger.info(
            f"Cache cleanup completed: cleaned {result['cleaned_delayed_tasks']} delayed tasks"
        )

        return {
            "task": "cleanup_expired_cache",
            "started_at": start_time.isoformat(),
            "completed_at": datetime.utcnow().isoformat(),
            "result": result,
        }

    except Exception as e:
        logger.error(f"Cache cleanup failed: {e}")
        raise self.retry(exc=e)


async def _verify_account_balance(user_id: str) -> Dict[str, Any]:
    """Verify account balance for a user."""
    from app.core.database import async_session_maker
    from app.services.data_integrity_service import data_integrity

    async with async_session_maker() as db:
        report = await data_integrity.verify_account_balances(db, UUID(user_id))

        return {
            "check_name": report.check_name,
            "status": report.status.value,
            "total_checked": report.total_checked,
            "issues_found": report.issues_found,
            "duration_ms": report.duration_ms,
            "issues": [
                {
                    "entity_type": issue.entity_type,
                    "entity_id": issue.entity_id,
                    "expected": issue.expected,
                    "actual": issue.actual,
                    "auto_fixable": issue.auto_fixable,
                }
                for issue in report.issues
            ],
        }


@celery_app.task(
    bind=True,
    name="app.tasks.integrity_tasks.verify_user_balance",
    max_retries=3,
    default_retry_delay=60,
)
def verify_user_balance(self, user_id: str) -> Dict[str, Any]:
    """Verify account balances for a specific user.

    Can be triggered after suspicious activity or user request.

    Args:
        user_id: UUID of user to verify

    Returns:
        Dict with balance verification results
    """
    logger.info(f"Starting balance verification for user: {user_id}")
    start_time = datetime.utcnow()

    try:
        result = run_async(_verify_account_balance(user_id))

        if result["issues_found"] > 0:
            logger.warning(
                f"Balance discrepancies found for user {user_id}: "
                f"{result['issues_found']} accounts with issues"
            )
        else:
            logger.info(f"All balances verified for user {user_id}")

        return {
            "task": "verify_user_balance",
            "user_id": user_id,
            "started_at": start_time.isoformat(),
            "completed_at": datetime.utcnow().isoformat(),
            "result": result,
        }

    except Exception as e:
        logger.error(f"Balance verification failed for {user_id}: {e}")
        raise self.retry(exc=e)


# ==================== Convenience Functions ====================

def trigger_user_check(user_id: str) -> str:
    """Trigger an async integrity check for a user.

    Args:
        user_id: User UUID to check

    Returns:
        Task ID for tracking
    """
    task = user_integrity_check.delay(user_id)
    return task.id


def trigger_balance_check(user_id: str) -> str:
    """Trigger an async balance verification for a user.

    Args:
        user_id: User UUID to check

    Returns:
        Task ID for tracking
    """
    task = verify_user_balance.delay(user_id)
    return task.id


def get_task_status(task_id: str) -> Dict[str, Any]:
    """Get status of a background task.

    Args:
        task_id: Celery task ID

    Returns:
        Dict with task status and result
    """
    from celery.result import AsyncResult

    result = AsyncResult(task_id, app=celery_app)
    return {
        "task_id": task_id,
        "status": result.status,
        "result": result.result if result.ready() else None,
        "traceback": result.traceback if result.failed() else None,
    }

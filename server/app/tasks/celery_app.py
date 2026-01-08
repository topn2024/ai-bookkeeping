"""Celery application configuration.

Provides background task processing for:
- Periodic data integrity verification
- Async operations that don't need immediate response
- Scheduled maintenance tasks

Reference: Design Document Chapter 33.4 - Data Integrity Guarantee

Usage:
    # Start worker
    celery -A app.tasks.celery_app worker --loglevel=info

    # Start beat scheduler
    celery -A app.tasks.celery_app beat --loglevel=info

    # Or combined
    celery -A app.tasks.celery_app worker --beat --loglevel=info
"""
import logging
from celery import Celery
from celery.schedules import crontab

from app.core.config import settings

logger = logging.getLogger(__name__)

# Use CELERY_BROKER_URL if set, otherwise fall back to REDIS_URL
broker_url = settings.CELERY_BROKER_URL or settings.REDIS_URL
result_backend = settings.CELERY_RESULT_BACKEND or settings.REDIS_URL

# Create Celery app
celery_app = Celery(
    "ai_bookkeeping",
    broker=broker_url,
    backend=result_backend,
    include=["app.tasks.integrity_tasks"],
)

# Celery configuration
celery_app.conf.update(
    # Timezone
    timezone=settings.CELERY_TIMEZONE,
    enable_utc=True,

    # Task settings
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    result_expires=3600,  # Results expire after 1 hour

    # Task execution settings
    task_acks_late=True,  # Acknowledge after task completion
    task_reject_on_worker_lost=True,
    task_time_limit=600,  # 10 minutes max per task
    task_soft_time_limit=540,  # Soft limit 9 minutes (allows cleanup)

    # Worker settings
    worker_prefetch_multiplier=1,  # Process one task at a time
    worker_concurrency=2,  # 2 concurrent workers for integrity checks

    # Retry settings
    task_default_retry_delay=60,  # 1 minute retry delay
    task_max_retries=3,

    # Beat scheduler settings (for periodic tasks)
    beat_schedule={
        # Daily full integrity check at 2 AM
        "daily-integrity-check": {
            "task": "app.tasks.integrity_tasks.periodic_integrity_check",
            "schedule": crontab(hour=2, minute=0),
            "options": {"queue": "integrity"},
        },
        # Weekly orphaned records cleanup at 3 AM Sunday
        "weekly-orphan-check": {
            "task": "app.tasks.integrity_tasks.check_orphaned_records",
            "schedule": crontab(hour=3, minute=0, day_of_week=0),
            "options": {"queue": "integrity"},
        },
        # Hourly cache cleanup
        "hourly-cache-cleanup": {
            "task": "app.tasks.integrity_tasks.cleanup_expired_cache",
            "schedule": crontab(minute=0),
            "options": {"queue": "maintenance"},
        },
    },

    # Task routing
    task_routes={
        "app.tasks.integrity_tasks.*": {"queue": "integrity"},
    },

    # Queue configuration
    task_queues={
        "default": {},
        "integrity": {},
        "maintenance": {},
    },
    task_default_queue="default",
)


def get_celery_app() -> Celery:
    """Get Celery application instance."""
    return celery_app


# Health check task
@celery_app.task(bind=True, name="app.tasks.health_check")
def health_check(self):
    """Simple health check task to verify Celery is working."""
    return {
        "status": "healthy",
        "worker": self.request.hostname,
        "task_id": self.request.id,
    }

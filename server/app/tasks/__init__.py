"""Background tasks package.

This package contains Celery configuration and task definitions for:
- Data integrity verification (periodic)
- User-level integrity checks (on-demand)
- Other background processing tasks

Reference: Design Document Chapter 33.4 - Data Integrity Guarantee
"""
from app.tasks.celery_app import celery_app

__all__ = ["celery_app"]

"""Logging configuration module."""
import logging
import logging.handlers
import sys
from contextvars import ContextVar
from pathlib import Path
from typing import Optional

from app.core.config import settings

# Context variable for request ID tracking
request_id_var: ContextVar[Optional[str]] = ContextVar("request_id", default=None)


class RequestIdFilter(logging.Filter):
    """Filter that adds request_id to log records."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = request_id_var.get() or "-"
        return True


class SensitiveDataFilter(logging.Filter):
    """Filter that masks sensitive data in log messages."""

    SENSITIVE_KEYWORDS = [
        "password",
        "secret",
        "token",
        "api_key",
        "apikey",
        "authorization",
        "credential",
    ]

    def filter(self, record: logging.LogRecord) -> bool:
        if isinstance(record.msg, str):
            msg_lower = record.msg.lower()
            for keyword in self.SENSITIVE_KEYWORDS:
                if keyword in msg_lower:
                    # Don't block, just warn
                    record.msg = f"[SENSITIVE DATA WARNING] {record.msg}"
                    break
        return True


def setup_logging() -> None:
    """Setup application logging configuration."""
    # Determine log level from settings
    log_level_name = settings.LOG_LEVEL.upper() if hasattr(settings, 'LOG_LEVEL') else 'INFO'
    if settings.DEBUG:
        log_level_name = 'DEBUG'
    log_level = getattr(logging, log_level_name, logging.INFO)

    # Create logs directory
    log_dir = Path("logs")
    log_dir.mkdir(exist_ok=True)

    # Log format with request_id
    log_format = (
        "%(asctime)s | %(levelname)-8s | %(request_id)s | "
        "%(name)s:%(funcName)s:%(lineno)d | %(message)s"
    )
    date_format = "%Y-%m-%d %H:%M:%S"

    # Create formatter
    formatter = logging.Formatter(log_format, datefmt=date_format)

    # Root logger configuration
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # Clear existing handlers
    root_logger.handlers.clear()

    # Console handler (stdout)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)
    console_handler.setFormatter(formatter)
    console_handler.addFilter(RequestIdFilter())
    console_handler.addFilter(SensitiveDataFilter())
    root_logger.addHandler(console_handler)

    # File handler with rotation (general logs)
    file_handler = logging.handlers.RotatingFileHandler(
        log_dir / "app.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setLevel(log_level)
    file_handler.setFormatter(formatter)
    file_handler.addFilter(RequestIdFilter())
    file_handler.addFilter(SensitiveDataFilter())
    root_logger.addHandler(file_handler)

    # Error file handler (errors only)
    error_handler = logging.handlers.RotatingFileHandler(
        log_dir / "error.log",
        maxBytes=10 * 1024 * 1024,  # 10MB
        backupCount=5,
        encoding="utf-8",
    )
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(formatter)
    error_handler.addFilter(RequestIdFilter())
    root_logger.addHandler(error_handler)

    # Suppress noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.INFO if settings.DEBUG else logging.WARNING
    )
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)

    # Log startup message
    logger = logging.getLogger(__name__)
    logger.info(f"Logging initialized - level: {logging.getLevelName(log_level)}")


def get_logger(name: str) -> logging.Logger:
    """Get a logger with the given name.

    Args:
        name: Logger name, typically __name__

    Returns:
        Configured logger instance
    """
    return logging.getLogger(name)

"""API Dependencies module."""

from .resource_access import (
    ResourceAccessChecker,
    get_user_resource,
    get_user_book,
    get_user_account,
    get_user_budget,
    get_user_category,
    verify_book_member_access,
)

__all__ = [
    "ResourceAccessChecker",
    "get_user_resource",
    "get_user_book",
    "get_user_account",
    "get_user_budget",
    "get_user_category",
    "verify_book_member_access",
]

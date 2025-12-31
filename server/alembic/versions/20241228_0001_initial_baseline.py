"""Initial baseline - existing database schema

Revision ID: 0001
Revises: None
Create Date: 2024-12-28

This migration represents the initial database schema created by SQLAlchemy ORM.
It's a baseline marker - the actual tables already exist.

Tables included:
- users
- books
- book_members
- accounts
- categories
- transactions
- budgets
- bill_reminders
- credit_cards
- debts
- recurring_transactions
- savings_goals
- admin_users
- admin_roles
- admin_logs
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade database schema.

    This is a baseline migration. If running on a fresh database,
    the tables are created by SQLAlchemy ORM on startup.
    This migration just marks the baseline version.
    """
    # Check if we're running on an existing database
    # If tables exist, this is just marking the baseline
    # If tables don't exist, they'll be created by ORM
    pass


def downgrade() -> None:
    """Downgrade database schema.

    WARNING: This will drop ALL baseline tables!
    Only use this in development/testing.
    """
    # In production, we should never drop baseline tables
    # This is here for development/testing purposes only

    # Drop all baseline tables in reverse dependency order
    # Uncomment below ONLY if you need to completely reset the database

    # op.drop_table('admin_logs')
    # op.drop_table('admin_users')
    # op.drop_table('admin_roles')
    # op.drop_table('savings_goals')
    # op.drop_table('recurring_transactions')
    # op.drop_table('debts')
    # op.drop_table('credit_cards')
    # op.drop_table('bill_reminders')
    # op.drop_table('budgets')
    # op.drop_table('transactions')
    # op.drop_table('categories')
    # op.drop_table('accounts')
    # op.drop_table('book_members')
    # op.drop_table('books')
    # op.drop_table('users')
    pass

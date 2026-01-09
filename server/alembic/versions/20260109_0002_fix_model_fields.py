"""Fix model fields - add missing columns to Budget, Book, Account

Revision ID: 20260109_0002
Revises: 20260109_0001
Create Date: 2026-01-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '20260109_0002'
down_revision: Union[str, None] = '20260109_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add missing fields to budgets table
    op.add_column('budgets', sa.Column('name', sa.String(100), nullable=False, server_default='Budget'))
    op.add_column('budgets', sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'))
    op.add_column('budgets', sa.Column('updated_at', sa.DateTime(), nullable=True))

    # Add missing fields to books table
    op.add_column('books', sa.Column('is_archived', sa.Boolean(), nullable=False, server_default='false'))

    # Add missing fields to accounts table
    op.add_column('accounts', sa.Column('currency', sa.String(10), nullable=False, server_default='CNY'))
    op.add_column('accounts', sa.Column('updated_at', sa.DateTime(), nullable=True))

    # Add missing fields to transactions table for cross-region and geofence
    op.add_column('transactions', sa.Column('geofence_region', sa.String(100), nullable=True))
    op.add_column('transactions', sa.Column('is_cross_region', sa.Boolean(), nullable=False, server_default='false'))


def downgrade() -> None:
    # Remove fields from transactions
    op.drop_column('transactions', 'is_cross_region')
    op.drop_column('transactions', 'geofence_region')

    # Remove fields from accounts
    op.drop_column('accounts', 'updated_at')
    op.drop_column('accounts', 'currency')

    # Remove fields from books
    op.drop_column('books', 'is_archived')

    # Remove fields from budgets
    op.drop_column('budgets', 'updated_at')
    op.drop_column('budgets', 'is_active')
    op.drop_column('budgets', 'name')

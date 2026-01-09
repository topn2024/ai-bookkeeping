"""Add Money Age tables and missing transaction fields

Revision ID: 20260109_0003
Revises: 20260109_0002
Create Date: 2026-01-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260109_0003'
down_revision: Union[str, None] = '20260109_0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add missing fields to transactions table
    op.add_column('transactions', sa.Column('money_age', sa.Integer(), nullable=True))
    op.add_column('transactions', sa.Column('money_age_level', sa.String(20), nullable=True))
    op.add_column('transactions', sa.Column('resource_pool_id', postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column('transactions', sa.Column('source_file_url', sa.String(500), nullable=True))
    op.add_column('transactions', sa.Column('source_file_type', sa.String(50), nullable=True))
    op.add_column('transactions', sa.Column('source_file_size', sa.Integer(), nullable=True))
    op.add_column('transactions', sa.Column('recognition_raw_response', sa.String(5000), nullable=True))
    op.add_column('transactions', sa.Column('recognition_timestamp', sa.DateTime(), nullable=True))
    op.add_column('transactions', sa.Column('source_file_expires_at', sa.DateTime(), nullable=True))
    op.add_column('transactions', sa.Column('visibility', sa.Integer(), nullable=False, server_default='1'))

    # Create resource_pools table
    op.create_table(
        'resource_pools',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id'), nullable=False),
        sa.Column('income_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id'), nullable=False),
        sa.Column('original_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('remaining_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('consumed_amount', sa.Numeric(15, 2), nullable=False, server_default='0'),
        sa.Column('income_date', sa.Date(), nullable=False),
        sa.Column('first_consumed_date', sa.Date(), nullable=True),
        sa.Column('last_consumed_date', sa.Date(), nullable=True),
        sa.Column('fully_consumed_date', sa.Date(), nullable=True),
        sa.Column('is_fully_consumed', sa.Boolean(), server_default='false'),
        sa.Column('consumption_count', sa.Integer(), server_default='0'),
        sa.Column('account_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('accounts.id'), nullable=False),
        sa.Column('income_category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_resource_pool_user_book', 'resource_pools', ['user_id', 'book_id'])
    op.create_index('idx_resource_pool_transaction', 'resource_pools', ['income_transaction_id'])
    op.create_index('idx_resource_pool_date', 'resource_pools', ['income_date'])

    # Create consumption_records table
    op.create_table(
        'consumption_records',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('resource_pool_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('resource_pools.id'), nullable=False),
        sa.Column('expense_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id'), nullable=False),
        sa.Column('consumed_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('consumption_date', sa.Date(), nullable=False),
        sa.Column('money_age_days', sa.Integer(), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_consumption_expense', 'consumption_records', ['expense_transaction_id'])
    op.create_index('idx_consumption_pool', 'consumption_records', ['resource_pool_id'])
    op.create_index('idx_consumption_date', 'consumption_records', ['consumption_date'])

    # Create money_age_snapshots table
    op.create_table(
        'money_age_snapshots',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id'), nullable=False),
        sa.Column('snapshot_date', sa.Date(), nullable=False),
        sa.Column('snapshot_type', sa.String(20), server_default='daily'),
        sa.Column('avg_money_age', sa.Numeric(10, 2), nullable=False),
        sa.Column('median_money_age', sa.Integer(), nullable=True),
        sa.Column('min_money_age', sa.Integer(), nullable=True),
        sa.Column('max_money_age', sa.Integer(), nullable=True),
        sa.Column('health_level', sa.String(20), nullable=False),
        sa.Column('health_count', sa.Integer(), server_default='0'),
        sa.Column('warning_count', sa.Integer(), server_default='0'),
        sa.Column('danger_count', sa.Integer(), server_default='0'),
        sa.Column('total_resource_pools', sa.Integer(), server_default='0'),
        sa.Column('active_resource_pools', sa.Integer(), server_default='0'),
        sa.Column('total_remaining_amount', sa.Numeric(15, 2), server_default='0'),
        sa.Column('total_transactions', sa.Integer(), server_default='0'),
        sa.Column('expense_transactions', sa.Integer(), server_default='0'),
        sa.Column('income_transactions', sa.Integer(), server_default='0'),
        sa.Column('category_breakdown', postgresql.JSONB(), nullable=True),
        sa.Column('monthly_trend', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_snapshot_user_date', 'money_age_snapshots', ['user_id', 'snapshot_date'])
    op.create_index('idx_snapshot_book', 'money_age_snapshots', ['book_id'])

    # Create money_age_configs table
    op.create_table(
        'money_age_configs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False, unique=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id'), nullable=False),
        sa.Column('consumption_strategy', sa.String(20), server_default='fifo'),
        sa.Column('health_threshold', sa.Integer(), server_default='30'),
        sa.Column('warning_threshold', sa.Integer(), server_default='60'),
        sa.Column('enable_daily_snapshot', sa.Boolean(), server_default='true'),
        sa.Column('enable_weekly_snapshot', sa.Boolean(), server_default='true'),
        sa.Column('enable_monthly_snapshot', sa.Boolean(), server_default='true'),
        sa.Column('enable_notifications', sa.Boolean(), server_default='true'),
        sa.Column('notify_on_warning', sa.Boolean(), server_default='true'),
        sa.Column('notify_on_danger', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # Add foreign key for resource_pool_id in transactions
    op.create_foreign_key(
        'fk_transactions_resource_pool',
        'transactions', 'resource_pools',
        ['resource_pool_id'], ['id']
    )


def downgrade() -> None:
    # Drop foreign key
    op.drop_constraint('fk_transactions_resource_pool', 'transactions', type_='foreignkey')

    # Drop tables
    op.drop_table('money_age_configs')

    op.drop_index('idx_snapshot_book', table_name='money_age_snapshots')
    op.drop_index('idx_snapshot_user_date', table_name='money_age_snapshots')
    op.drop_table('money_age_snapshots')

    op.drop_index('idx_consumption_date', table_name='consumption_records')
    op.drop_index('idx_consumption_pool', table_name='consumption_records')
    op.drop_index('idx_consumption_expense', table_name='consumption_records')
    op.drop_table('consumption_records')

    op.drop_index('idx_resource_pool_date', table_name='resource_pools')
    op.drop_index('idx_resource_pool_transaction', table_name='resource_pools')
    op.drop_index('idx_resource_pool_user_book', table_name='resource_pools')
    op.drop_table('resource_pools')

    # Drop columns from transactions
    op.drop_column('transactions', 'visibility')
    op.drop_column('transactions', 'source_file_expires_at')
    op.drop_column('transactions', 'recognition_timestamp')
    op.drop_column('transactions', 'recognition_raw_response')
    op.drop_column('transactions', 'source_file_size')
    op.drop_column('transactions', 'source_file_type')
    op.drop_column('transactions', 'source_file_url')
    op.drop_column('transactions', 'resource_pool_id')
    op.drop_column('transactions', 'money_age_level')
    op.drop_column('transactions', 'money_age')

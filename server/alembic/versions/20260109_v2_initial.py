"""Initial migration for v2.0

Revision ID: 20260109_v2_initial
Revises: 
Create Date: 2026-01-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260109_v2_initial'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ==================== Users ====================
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('phone', sa.String(20), unique=True, nullable=True),
        sa.Column('email', sa.String(100), unique=True, nullable=True),
        sa.Column('password_hash', sa.String(255), nullable=True),  # Nullable for OAuth users
        sa.Column('nickname', sa.String(50), nullable=True),
        sa.Column('avatar_url', sa.String(500), nullable=True),
        sa.Column('member_level', sa.Integer(), server_default='0'),
        sa.Column('member_expire_at', sa.DateTime(), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # ==================== Books ====================
    op.create_table(
        'books',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('book_type', sa.Integer(), server_default='0'),  # 0: personal, 1: family
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('cover_image', sa.String(500), nullable=True),
        sa.Column('currency', sa.String(10), server_default='CNY'),
        sa.Column('is_default', sa.Boolean(), server_default='false'),
        sa.Column('is_archived', sa.Boolean(), server_default='false'),
        sa.Column('settings', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_books_user_id', 'books', ['user_id'])

    # ==================== Accounts ====================
    op.create_table(
        'accounts',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('account_type', sa.Integer(), nullable=False),  # 1-5
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('balance', sa.Numeric(15, 2), server_default='0'),
        sa.Column('currency', sa.String(10), server_default='CNY'),
        sa.Column('credit_limit', sa.Numeric(15, 2), nullable=True),
        sa.Column('bill_day', sa.Integer(), nullable=True),
        sa.Column('repay_day', sa.Integer(), nullable=True),
        sa.Column('is_default', sa.Boolean(), server_default='false'),
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint('account_type >= 1 AND account_type <= 5', name='ck_accounts_type'),
    )
    op.create_index('idx_accounts_user_id', 'accounts', ['user_id'])

    # ==================== Categories ====================
    op.create_table(
        'categories',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=True),
        sa.Column('parent_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='CASCADE'), nullable=True),
        sa.Column('name', sa.String(50), nullable=False),
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('category_type', sa.Integer(), nullable=False),  # 1: expense, 2: income
        sa.Column('sort_order', sa.Integer(), server_default='0'),
        sa.Column('is_system', sa.Boolean(), server_default='false'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint('category_type IN (1, 2)', name='ck_categories_type'),
    )
    op.create_index('idx_categories_user_id', 'categories', ['user_id'])
    op.create_index('idx_categories_parent_id', 'categories', ['parent_id'])
    op.create_index('idx_categories_type', 'categories', ['category_type'])

    # ==================== Transactions ====================
    op.create_table(
        'transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('account_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('accounts.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('target_account_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('accounts.id', ondelete='SET NULL'), nullable=True),
        sa.Column('category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('transaction_type', sa.Integer(), nullable=False),  # 1: expense, 2: income, 3: transfer
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('fee', sa.Numeric(15, 2), server_default='0'),
        sa.Column('transaction_date', sa.Date(), nullable=False),
        sa.Column('transaction_time', sa.Time(), nullable=True),
        sa.Column('note', sa.String(500), nullable=True),
        sa.Column('tags', postgresql.ARRAY(sa.String(50)), nullable=True),
        sa.Column('images', postgresql.ARRAY(sa.String(500)), nullable=True),
        sa.Column('location', sa.String(200), nullable=True),
        # Location Intelligence fields
        sa.Column('location_latitude', sa.Numeric(10, 7), nullable=True),
        sa.Column('location_longitude', sa.Numeric(10, 7), nullable=True),
        sa.Column('location_place_name', sa.String(200), nullable=True),
        sa.Column('location_address', sa.String(500), nullable=True),
        sa.Column('location_city', sa.String(100), nullable=True),
        sa.Column('location_district', sa.String(100), nullable=True),
        sa.Column('location_type', sa.Integer(), nullable=True),
        sa.Column('location_poi_id', sa.String(100), nullable=True),
        sa.Column('geofence_region', sa.String(100), nullable=True),
        sa.Column('is_cross_region', sa.Boolean(), server_default='false'),
        # Money Age fields
        sa.Column('money_age', sa.Integer(), nullable=True),
        sa.Column('money_age_level', sa.String(20), nullable=True),
        sa.Column('resource_pool_id', postgresql.UUID(as_uuid=True), nullable=True),  # FK added later
        # Reimbursement and stats
        sa.Column('is_reimbursable', sa.Boolean(), server_default='false'),
        sa.Column('is_reimbursed', sa.Boolean(), server_default='false'),
        sa.Column('is_exclude_stats', sa.Boolean(), server_default='false'),
        sa.Column('source', sa.Integer(), server_default='0'),  # 0: manual, 1: image, 2: voice, 3: email
        sa.Column('ai_confidence', sa.Numeric(3, 2), nullable=True),
        # Source file fields
        sa.Column('source_file_url', sa.String(500), nullable=True),
        sa.Column('source_file_type', sa.String(50), nullable=True),
        sa.Column('source_file_size', sa.Integer(), nullable=True),
        sa.Column('recognition_raw_response', sa.Text(), nullable=True),
        sa.Column('recognition_timestamp', sa.DateTime(), nullable=True),
        sa.Column('source_file_expires_at', sa.DateTime(), nullable=True),
        # Visibility
        sa.Column('visibility', sa.Integer(), server_default='1'),  # 0: private, 1: all_members, 2: admins_only
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint('transaction_type IN (1, 2, 3)', name='ck_transactions_type'),
        sa.CheckConstraint('amount > 0', name='ck_transactions_amount_positive'),
    )
    # Transaction indexes
    op.create_index('idx_transactions_user_id', 'transactions', ['user_id'])
    op.create_index('idx_transactions_book_id', 'transactions', ['book_id'])
    op.create_index('idx_transactions_account_id', 'transactions', ['account_id'])
    op.create_index('idx_transactions_category_id', 'transactions', ['category_id'])
    op.create_index('idx_transactions_type', 'transactions', ['transaction_type'])
    op.create_index('idx_transactions_date', 'transactions', ['transaction_date'])
    op.create_index('idx_transactions_user_date', 'transactions', ['user_id', 'transaction_date'])
    op.create_index('idx_transactions_book_date', 'transactions', ['book_id', 'transaction_date'])
    op.execute('CREATE INDEX idx_transactions_tags ON transactions USING GIN (tags)')

    # ==================== Budgets ====================
    op.create_table(
        'budgets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='CASCADE'), nullable=True),
        sa.Column('name', sa.String(100), server_default='Budget'),
        sa.Column('budget_type', sa.Integer(), nullable=False),  # 1: monthly, 2: yearly
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=True),  # NULL for yearly
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint('amount > 0', name='ck_budgets_amount_positive'),
        sa.CheckConstraint('budget_type IN (1, 2)', name='ck_budgets_type'),
    )
    op.create_index('idx_budgets_user_id', 'budgets', ['user_id'])
    op.create_index('idx_budgets_book_id', 'budgets', ['book_id'])
    op.create_index('idx_budgets_category_id', 'budgets', ['category_id'])
    op.create_index('idx_budgets_user_year_month', 'budgets', ['user_id', 'year', 'month'])

    # ==================== Expense Targets ====================
    op.create_table(
        'expense_targets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=False),
        sa.Column('target_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_expense_targets_user_book', 'expense_targets', ['user_id', 'book_id'])

    # ==================== Email Bindings ====================
    op.create_table(
        'email_bindings',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('email_address', sa.String(255), nullable=False),
        sa.Column('email_type', sa.Integer(), nullable=False),  # 1: alipay, 2: wechat, 3: bank
        sa.Column('imap_server', sa.String(255), nullable=True),
        sa.Column('imap_port', sa.Integer(), nullable=True),
        sa.Column('imap_password', sa.String(500), nullable=True),  # Encrypted
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('last_sync_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_email_bindings_user_id', 'email_bindings', ['user_id'])

    # ==================== OAuth Providers ====================
    op.create_table(
        'oauth_providers',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('provider', sa.String(20), nullable=False),  # google, wechat, apple
        sa.Column('provider_user_id', sa.String(255), nullable=False),
        sa.Column('access_token', sa.Text(), nullable=True),  # Encrypted
        sa.Column('refresh_token', sa.Text(), nullable=True),  # Encrypted
        sa.Column('token_expires_at', sa.DateTime(), nullable=True),
        sa.Column('provider_data', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('provider', 'provider_user_id', name='uq_oauth_provider_user'),
    )
    op.create_index('idx_oauth_providers_user_id', 'oauth_providers', ['user_id'])

    # ==================== Backups ====================
    op.create_table(
        'backups',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('file_url', sa.String(500), nullable=True),
        sa.Column('file_size', sa.BigInteger(), nullable=True),
        sa.Column('data', postgresql.JSONB(), nullable=True),  # Changed to JSONB
        sa.Column('backup_type', sa.Integer(), server_default='0'),  # 0: manual, 1: auto
        sa.Column('status', sa.Integer(), server_default='0'),  # 0: pending, 1: completed, 2: failed
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_backups_user_id', 'backups', ['user_id'])

    # ==================== App Versions ====================
    op.create_table(
        'app_versions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('version_name', sa.String(20), nullable=False),
        sa.Column('version_code', sa.Integer(), nullable=False),
        sa.Column('platform', sa.String(20), server_default='android'),
        sa.Column('file_url', sa.String(500), nullable=True),
        sa.Column('file_size', sa.BigInteger(), nullable=True),
        sa.Column('file_md5', sa.String(32), nullable=True),
        sa.Column('patch_from_version', sa.String(20), nullable=True),
        sa.Column('patch_from_code', sa.Integer(), nullable=True),
        sa.Column('patch_file_url', sa.String(500), nullable=True),
        sa.Column('patch_file_size', sa.BigInteger(), nullable=True),
        sa.Column('patch_file_md5', sa.String(32), nullable=True),
        sa.Column('release_notes', sa.Text(), nullable=True),
        sa.Column('release_notes_en', sa.Text(), nullable=True),
        sa.Column('is_force_update', sa.Boolean(), server_default='false'),
        sa.Column('min_supported_version', sa.String(20), nullable=True),
        sa.Column('rollout_percentage', sa.Integer(), server_default='100'),
        sa.Column('rollout_start_date', sa.DateTime(), nullable=True),
        sa.Column('status', sa.Integer(), server_default='0'),
        sa.Column('published_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('created_by', sa.String(100), nullable=True),
    )

    # ==================== Upgrade Analytics ====================
    op.create_table(
        'upgrade_analytics',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('event_type', sa.String(50), nullable=False),
        sa.Column('platform', sa.String(20), server_default='android'),
        sa.Column('from_version', sa.String(20), nullable=True),
        sa.Column('to_version', sa.String(20), nullable=True),
        sa.Column('from_build', sa.Integer(), nullable=True),
        sa.Column('to_build', sa.Integer(), nullable=True),
        sa.Column('download_progress', sa.Integer(), nullable=True),
        sa.Column('download_size', sa.Integer(), nullable=True),
        sa.Column('download_duration_ms', sa.Integer(), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('error_code', sa.String(50), nullable=True),
        sa.Column('device_id', sa.String(100), nullable=True),
        sa.Column('device_model', sa.String(100), nullable=True),
        sa.Column('extra_data', sa.Text(), nullable=True),
        sa.Column('event_time', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_upgrade_analytics_event_type', 'upgrade_analytics', ['event_type'])
    op.create_index('idx_upgrade_analytics_device_id', 'upgrade_analytics', ['device_id'])
    op.create_index('idx_upgrade_analytics_event_time', 'upgrade_analytics', ['event_time'])
    op.create_index('idx_upgrade_analytics_version', 'upgrade_analytics', ['to_version', 'event_type'])
    op.create_index('idx_upgrade_analytics_platform_event', 'upgrade_analytics', ['platform', 'event_type'])

    # ==================== Family Book: Book Members ====================
    op.create_table(
        'book_members',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('role', sa.Integer(), server_default='1'),  # 0: owner, 1: admin, 2: member
        sa.Column('nickname', sa.String(50), nullable=True),
        sa.Column('invited_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('joined_at', sa.DateTime(), nullable=True),
        sa.Column('settings', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.UniqueConstraint('book_id', 'user_id', name='uq_book_members_book_user'),
    )
    op.create_index('idx_book_members_book_id', 'book_members', ['book_id'])
    op.create_index('idx_book_members_user_id', 'book_members', ['user_id'])

    # ==================== Family Book: Invitations ====================
    op.create_table(
        'book_invitations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('inviter_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('invite_code', sa.String(20), unique=True, nullable=False),
        sa.Column('role', sa.Integer(), server_default='2'),
        sa.Column('max_uses', sa.Integer(), server_default='1'),
        sa.Column('used_count', sa.Integer(), server_default='0'),
        sa.Column('expires_at', sa.DateTime(), nullable=True),
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_book_invitations_code', 'book_invitations', ['invite_code'])

    # ==================== Family Book: Family Budgets ====================
    op.create_table(
        'family_budgets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('period', sa.String(20), nullable=False),  # monthly/yearly
        sa.Column('strategy', sa.Integer(), server_default='0'),  # 0: equal, 1: proportional, 2: custom
        sa.Column('total_budget', sa.Numeric(15, 2), nullable=False),
        sa.Column('rules', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_family_budgets_book_id', 'family_budgets', ['book_id'])

    # ==================== Family Book: Member Budgets ====================
    op.create_table(
        'member_budgets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('family_budget_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('family_budgets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('allocated', sa.Numeric(15, 2), server_default='0'),
        sa.Column('spent', sa.Numeric(15, 2), server_default='0'),
        sa.Column('category_spent', postgresql.JSONB(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # ==================== Family Book: Saving Goals ====================
    op.create_table(
        'family_saving_goals',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('target_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('current_amount', sa.Numeric(15, 2), server_default='0'),
        sa.Column('deadline', sa.DateTime(), nullable=True),
        sa.Column('status', sa.Integer(), server_default='0'),  # 0: active, 1: completed, 2: cancelled
        sa.Column('created_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_family_saving_goals_book_id', 'family_saving_goals', ['book_id'])

    # ==================== Family Book: Goal Contributions ====================
    op.create_table(
        'goal_contributions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('goal_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('family_saving_goals.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('note', sa.String(200), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # ==================== Family Book: Transaction Splits ====================
    op.create_table(
        'transaction_splits',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('split_type', sa.Integer(), server_default='0'),  # 0: equal, 1: percentage, 2: amount, 3: shares
        sa.Column('status', sa.Integer(), server_default='0'),  # 0: pending, 1: settled
        sa.Column('settled_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # ==================== Family Book: Split Participants ====================
    op.create_table(
        'split_participants',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('split_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transaction_splits.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('percentage', sa.Numeric(5, 2), nullable=True),
        sa.Column('shares', sa.Integer(), nullable=True),
        sa.Column('is_payer', sa.Boolean(), server_default='false'),
        sa.Column('is_settled', sa.Boolean(), server_default='false'),
        sa.Column('settled_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # ==================== Location: GeoFences ====================
    op.create_table(
        'geo_fences',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('center_latitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('center_longitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('radius_meters', sa.Float(), server_default='100'),
        sa.Column('place_name', sa.String(200), nullable=True),
        sa.Column('action', sa.Integer(), server_default='4'),  # GeoFenceAction enum
        sa.Column('linked_category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id'), nullable=True),
        sa.Column('linked_vault_id', sa.String(100), nullable=True),
        sa.Column('budget_limit', sa.Numeric(15, 2), nullable=True),
        sa.Column('is_enabled', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_geo_fences_user_id', 'geo_fences', ['user_id'])

    # ==================== Location: Frequent Locations ====================
    op.create_table(
        'frequent_locations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('latitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('longitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('place_name', sa.String(200), nullable=True),
        sa.Column('address', sa.String(500), nullable=True),
        sa.Column('city', sa.String(100), nullable=True),
        sa.Column('district', sa.String(100), nullable=True),
        sa.Column('location_type', sa.Integer(), nullable=True),
        sa.Column('poi_id', sa.String(100), nullable=True),
        sa.Column('visit_count', sa.Integer(), server_default='1'),
        sa.Column('total_spent', sa.Numeric(15, 2), server_default='0'),
        sa.Column('default_category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id'), nullable=True),
        sa.Column('default_vault_id', sa.String(100), nullable=True),
        sa.Column('last_visit_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_frequent_locations_user_id', 'frequent_locations', ['user_id'])
    op.create_index('idx_frequent_locations_coords', 'frequent_locations', ['latitude', 'longitude'])
    op.create_index('idx_frequent_locations_poi_id', 'frequent_locations', ['poi_id'])

    # ==================== Location: User Home Locations ====================
    op.create_table(
        'user_home_locations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('location_role', sa.Integer(), server_default='0'),  # 0: home, 1: work
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('latitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('longitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('city', sa.String(100), nullable=True),
        sa.Column('radius_meters', sa.Float(), server_default='5000'),
        sa.Column('is_primary', sa.Boolean(), server_default='false'),
        sa.Column('is_enabled', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_user_home_locations_user_id', 'user_home_locations', ['user_id'])

    # ==================== Money Age: Resource Pools ====================
    op.create_table(
        'resource_pools',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('income_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('original_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('remaining_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('consumed_amount', sa.Numeric(15, 2), server_default='0'),
        sa.Column('income_date', sa.Date(), nullable=False),
        sa.Column('first_consumed_date', sa.Date(), nullable=True),
        sa.Column('last_consumed_date', sa.Date(), nullable=True),
        sa.Column('fully_consumed_date', sa.Date(), nullable=True),
        sa.Column('is_fully_consumed', sa.Boolean(), server_default='false'),
        sa.Column('consumption_count', sa.Integer(), server_default='0'),
        sa.Column('account_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('accounts.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('income_category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_resource_pool_user_book', 'resource_pools', ['user_id', 'book_id'])
    op.create_index('idx_resource_pool_transaction', 'resource_pools', ['income_transaction_id'])
    op.create_index('idx_resource_pool_date', 'resource_pools', ['income_date'])

    # Add FK from transactions to resource_pools
    op.create_foreign_key(
        'fk_transactions_resource_pool',
        'transactions', 'resource_pools',
        ['resource_pool_id'], ['id'],
        ondelete='SET NULL'
    )

    # ==================== Money Age: Consumption Records ====================
    op.create_table(
        'consumption_records',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('resource_pool_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('resource_pools.id', ondelete='CASCADE'), nullable=False),
        sa.Column('expense_transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False),
        sa.Column('consumed_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('consumption_date', sa.Date(), nullable=False),
        sa.Column('money_age_days', sa.Integer(), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_consumption_expense', 'consumption_records', ['expense_transaction_id'])
    op.create_index('idx_consumption_pool', 'consumption_records', ['resource_pool_id'])
    op.create_index('idx_consumption_date', 'consumption_records', ['consumption_date'])

    # ==================== Money Age: Snapshots ====================
    op.create_table(
        'money_age_snapshots',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
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

    # ==================== Money Age: Configs ====================
    op.create_table(
        'money_age_configs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
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

    # ==================== Admin: Admin Users ====================
    op.create_table(
        'admin_users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('username', sa.String(50), unique=True, nullable=False),
        sa.Column('password_hash', sa.String(255), nullable=False),
        sa.Column('email', sa.String(100), unique=True, nullable=True),
        sa.Column('role', sa.String(20), server_default='admin'),  # admin, super_admin
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('last_login_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )

    # ==================== Admin: Admin Logs ====================
    op.create_table(
        'admin_logs',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('admin_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('admin_users.id'), nullable=True),
        sa.Column('action', sa.String(100), nullable=False),
        sa.Column('resource_type', sa.String(50), nullable=True),
        sa.Column('resource_id', sa.String(100), nullable=True),
        sa.Column('details', postgresql.JSONB(), nullable=True),
        sa.Column('ip_address', sa.String(50), nullable=True),
        sa.Column('user_agent', sa.String(500), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('idx_admin_logs_admin_id', 'admin_logs', ['admin_id'])
    op.create_index('idx_admin_logs_action', 'admin_logs', ['action'])
    op.create_index('idx_admin_logs_created_at', 'admin_logs', ['created_at'])


def downgrade() -> None:
    # Drop tables in reverse order
    op.drop_table('admin_logs')
    op.drop_table('admin_users')
    op.drop_table('money_age_configs')
    op.drop_table('money_age_snapshots')
    op.drop_table('consumption_records')
    op.drop_constraint('fk_transactions_resource_pool', 'transactions', type_='foreignkey')
    op.drop_table('resource_pools')
    op.drop_table('user_home_locations')
    op.drop_table('frequent_locations')
    op.drop_table('geo_fences')
    op.drop_table('split_participants')
    op.drop_table('transaction_splits')
    op.drop_table('goal_contributions')
    op.drop_table('family_saving_goals')
    op.drop_table('member_budgets')
    op.drop_table('family_budgets')
    op.drop_table('book_invitations')
    op.drop_table('book_members')
    op.drop_table('upgrade_analytics')
    op.drop_table('app_versions')
    op.drop_table('backups')
    op.drop_table('oauth_providers')
    op.drop_table('email_bindings')
    op.drop_table('expense_targets')
    op.drop_table('budgets')
    op.drop_table('transactions')
    op.drop_table('categories')
    op.drop_table('accounts')
    op.drop_table('books')
    op.drop_table('users')

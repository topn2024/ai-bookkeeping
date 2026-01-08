"""Initial V2 schema - Complete database structure

Revision ID: 20260108_0001
Revises:
Create Date: 2026-01-08

This migration creates the complete V2 database schema including:
- User and authentication tables
- Book and collaboration tables (family book support)
- Transaction and financial tables
- Budget and goal tracking tables
- Admin management tables
- App upgrade tracking tables
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260108_0001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # === Admin permissions ===
    op.create_table(
        'admin_permissions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('code', sa.String(100), nullable=False, unique=True),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('module', sa.String(50), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # === Admin roles ===
    op.create_table(
        'admin_roles',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('name', sa.String(50), nullable=False, unique=True),
        sa.Column('display_name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('is_system', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
    )

    # === App versions ===
    op.create_table(
        'app_versions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('version_name', sa.String(20), nullable=False),
        sa.Column('version_code', sa.Integer(), nullable=False),
        sa.Column('platform', sa.String(20), nullable=False),
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
        sa.Column('is_force_update', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('min_supported_version', sa.String(20), nullable=True),
        sa.Column('rollout_percentage', sa.Integer(), nullable=False, server_default='100'),
        sa.Column('rollout_start_date', sa.DateTime(), nullable=True),
        sa.Column('status', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('published_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('created_by', sa.String(100), nullable=True),
    )
    op.create_index('ix_app_versions_platform_version', 'app_versions', ['platform', 'version_code'], unique=True)

    # === Upgrade analytics ===
    op.create_table(
        'upgrade_analytics',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('event_type', sa.String(50), nullable=False),
        sa.Column('platform', sa.String(20), nullable=False),
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
    op.create_index('ix_upgrade_analytics_event_type', 'upgrade_analytics', ['event_type'])
    op.create_index('ix_upgrade_analytics_platform', 'upgrade_analytics', ['platform'])

    # === Users ===
    op.create_table(
        'users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('phone', sa.String(20), nullable=True, unique=True),
        sa.Column('email', sa.String(100), nullable=True, unique=True),
        sa.Column('password_hash', sa.String(255), nullable=True),
        sa.Column('nickname', sa.String(50), nullable=True),
        sa.Column('avatar_url', sa.String(500), nullable=True),
        sa.Column('member_level', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('member_expire_at', sa.DateTime(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
    )

    # === Accounts ===
    op.create_table(
        'accounts',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('account_type', sa.Integer(), nullable=False),
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('balance', sa.Numeric(15, 2), nullable=False, server_default='0'),
        sa.Column('credit_limit', sa.Numeric(15, 2), nullable=True),
        sa.Column('bill_day', sa.Integer(), nullable=True),
        sa.Column('repay_day', sa.Integer(), nullable=True),
        sa.Column('is_default', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_accounts_user_id', 'accounts', ['user_id'])

    # === Admin role permissions ===
    op.create_table(
        'admin_role_permissions',
        sa.Column('role_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('admin_roles.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('permission_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('admin_permissions.id', ondelete='CASCADE'), primary_key=True),
    )

    # === Admin users ===
    op.create_table(
        'admin_users',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('username', sa.String(50), nullable=False, unique=True),
        sa.Column('email', sa.String(100), nullable=True, unique=True),
        sa.Column('password_hash', sa.String(255), nullable=False),
        sa.Column('display_name', sa.String(100), nullable=True),
        sa.Column('avatar_url', sa.String(500), nullable=True),
        sa.Column('phone', sa.String(20), nullable=True),
        sa.Column('role_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('admin_roles.id'), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('is_superadmin', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('mfa_enabled', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('mfa_secret', sa.String(100), nullable=True),
        sa.Column('last_login_at', sa.DateTime(), nullable=True),
        sa.Column('last_login_ip', sa.String(50), nullable=True),
        sa.Column('login_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('failed_login_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('locked_until', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('created_by', postgresql.UUID(as_uuid=True), nullable=True),
    )

    # === Backups ===
    op.create_table(
        'backups',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('backup_type', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('data', sa.Text(), nullable=False),
        sa.Column('transaction_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('account_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('category_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('book_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('budget_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('credit_card_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('debt_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('savings_goal_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('bill_reminder_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('recurring_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('size', sa.BigInteger(), nullable=False),
        sa.Column('device_name', sa.String(100), nullable=True),
        sa.Column('device_id', sa.String(100), nullable=True),
        sa.Column('app_version', sa.String(20), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_backups_user_id', 'backups', ['user_id'])

    # === Books ===
    op.create_table(
        'books',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('cover_image', sa.String(500), nullable=True),
        sa.Column('book_type', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_default', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('currency', sa.String(10), nullable=False, server_default='CNY'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('settings', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.create_index('ix_books_user_id', 'books', ['user_id'])

    # === Categories ===
    op.create_table(
        'categories',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=True),
        sa.Column('parent_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='CASCADE'), nullable=True),
        sa.Column('name', sa.String(50), nullable=False),
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('category_type', sa.Integer(), nullable=False),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_system', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_categories_user_id', 'categories', ['user_id'])

    # === Email bindings ===
    op.create_table(
        'email_bindings',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('email', sa.String(100), nullable=False),
        sa.Column('email_type', sa.Integer(), nullable=False),
        sa.Column('access_token', sa.Text(), nullable=True),
        sa.Column('refresh_token', sa.Text(), nullable=True),
        sa.Column('token_expires_at', sa.DateTime(), nullable=True),
        sa.Column('imap_server', sa.String(100), nullable=True),
        sa.Column('imap_port', sa.Integer(), nullable=True),
        sa.Column('imap_password', sa.Text(), nullable=True),
        sa.Column('last_sync_at', sa.DateTime(), nullable=True),
        sa.Column('last_sync_message_id', sa.String(200), nullable=True),
        sa.Column('sync_error', sa.String(500), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_email_bindings_user_id', 'email_bindings', ['user_id'])

    # === OAuth providers ===
    op.create_table(
        'oauth_providers',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('provider', sa.String(20), nullable=False),
        sa.Column('provider_user_id', sa.String(200), nullable=False),
        sa.Column('provider_username', sa.String(100), nullable=True),
        sa.Column('provider_avatar', sa.String(500), nullable=True),
        sa.Column('provider_email', sa.String(100), nullable=True),
        sa.Column('provider_raw_data', sa.JSON(), nullable=True),
        sa.Column('access_token', sa.Text(), nullable=True),
        sa.Column('refresh_token', sa.Text(), nullable=True),
        sa.Column('token_expires_at', sa.DateTime(), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('last_login_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_oauth_providers_user_provider', 'oauth_providers', ['user_id', 'provider'], unique=True)

    # === Admin logs ===
    op.create_table(
        'admin_logs',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('admin_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('admin_users.id'), nullable=True),
        sa.Column('admin_username', sa.String(50), nullable=False),
        sa.Column('action', sa.String(100), nullable=False),
        sa.Column('action_name', sa.String(100), nullable=True),
        sa.Column('module', sa.String(50), nullable=True),
        sa.Column('target_type', sa.String(50), nullable=True),
        sa.Column('target_id', sa.String(100), nullable=True),
        sa.Column('target_name', sa.String(200), nullable=True),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('request_data', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('response_data', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('changes', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('ip_address', sa.String(50), nullable=True),
        sa.Column('user_agent', sa.String(500), nullable=True),
        sa.Column('request_method', sa.String(10), nullable=True),
        sa.Column('request_path', sa.String(500), nullable=True),
        sa.Column('status', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_admin_logs_admin_id', 'admin_logs', ['admin_id'])
    op.create_index('ix_admin_logs_created_at', 'admin_logs', ['created_at'])

    # === Book invitations ===
    op.create_table(
        'book_invitations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('inviter_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('role', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('code', sa.String(20), nullable=False, unique=True),
        sa.Column('voice_code', sa.String(6), nullable=True),
        sa.Column('status', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('max_uses', sa.Integer(), nullable=True),
        sa.Column('used_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_book_invitations_code', 'book_invitations', ['code'])
    op.create_index('ix_book_invitations_voice_code', 'book_invitations', ['voice_code'])

    # === Book members ===
    op.create_table(
        'book_members',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('role', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('nickname', sa.String(50), nullable=True),
        sa.Column('invited_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('joined_at', sa.DateTime(), nullable=False),
        sa.Column('settings', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.create_index('ix_book_members_book_user', 'book_members', ['book_id', 'user_id'], unique=True)

    # === Budgets ===
    op.create_table(
        'budgets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=True),
        sa.Column('category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='CASCADE'), nullable=True),
        sa.Column('budget_type', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_budgets_user_id', 'budgets', ['user_id'])

    # === Expense targets ===
    op.create_table(
        'expense_targets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=True),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('max_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id'), nullable=True),
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=False),
        sa.Column('icon_code', sa.Integer(), nullable=True),
        sa.Column('color_value', sa.Integer(), nullable=True),
        sa.Column('alert_threshold', sa.Integer(), nullable=True, server_default='80'),
        sa.Column('enable_notifications', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_expense_targets_user_id', 'expense_targets', ['user_id'])

    # === Family budgets ===
    op.create_table(
        'family_budgets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('period', sa.String(7), nullable=False),
        sa.Column('strategy', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('total_budget', sa.Numeric(15, 2), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('rules', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
    )
    op.create_index('ix_family_budgets_book_period', 'family_budgets', ['book_id', 'period'], unique=True)

    # === Family saving goals ===
    op.create_table(
        'family_saving_goals',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('icon', sa.String(50), nullable=True),
        sa.Column('target_amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('current_amount', sa.Numeric(15, 2), nullable=False, server_default='0'),
        sa.Column('deadline', sa.DateTime(), nullable=True),
        sa.Column('status', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_by', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('completed_at', sa.DateTime(), nullable=True),
    )

    # === Transactions ===
    op.create_table(
        'transactions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('books.id', ondelete='CASCADE'), nullable=True),
        sa.Column('account_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('accounts.id', ondelete='SET NULL'), nullable=True),
        sa.Column('target_account_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('accounts.id', ondelete='SET NULL'), nullable=True),
        sa.Column('category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id', ondelete='SET NULL'), nullable=True),
        sa.Column('transaction_type', sa.Integer(), nullable=False),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('fee', sa.Numeric(15, 2), nullable=True, server_default='0'),
        sa.Column('transaction_date', sa.Date(), nullable=False),
        sa.Column('transaction_time', sa.Time(), nullable=True),
        sa.Column('note', sa.String(500), nullable=True),
        sa.Column('tags', postgresql.ARRAY(sa.String(50)), nullable=True),
        sa.Column('images', postgresql.ARRAY(sa.String(500)), nullable=True),
        sa.Column('location', sa.String(200), nullable=True),
        sa.Column('is_reimbursable', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_reimbursed', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_exclude_stats', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('source', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('ai_confidence', sa.Numeric(3, 2), nullable=True),
        sa.Column('source_file_url', sa.String(500), nullable=True),
        sa.Column('source_file_type', sa.String(50), nullable=True),
        sa.Column('source_file_size', sa.Integer(), nullable=True),
        sa.Column('recognition_raw_response', sa.String(5000), nullable=True),
        sa.Column('recognition_timestamp', sa.DateTime(), nullable=True),
        sa.Column('source_file_expires_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.Column('visibility', sa.Integer(), nullable=False, server_default='1'),
    )
    op.create_index('ix_transactions_user_id', 'transactions', ['user_id'])
    op.create_index('ix_transactions_book_id', 'transactions', ['book_id'])
    op.create_index('ix_transactions_date', 'transactions', ['transaction_date'])

    # === Goal contributions ===
    op.create_table(
        'goal_contributions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('goal_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('family_saving_goals.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('note', sa.String(200), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # === Member budgets ===
    op.create_table(
        'member_budgets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('family_budget_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('family_budgets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('allocated', sa.Numeric(15, 2), nullable=False, server_default='0'),
        sa.Column('spent', sa.Numeric(15, 2), nullable=False, server_default='0'),
        sa.Column('category_spent', postgresql.JSONB(astext_type=sa.Text()), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_member_budgets_family_user', 'member_budgets', ['family_budget_id', 'user_id'], unique=True)

    # === Transaction splits ===
    op.create_table(
        'transaction_splits',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('transaction_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transactions.id', ondelete='CASCADE'), nullable=False, unique=True),
        sa.Column('split_type', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('status', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('settled_at', sa.DateTime(), nullable=True),
    )

    # === Split participants ===
    op.create_table(
        'split_participants',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('split_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('transaction_splits.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('amount', sa.Numeric(15, 2), nullable=False),
        sa.Column('percentage', sa.Numeric(5, 2), nullable=True),
        sa.Column('shares', sa.Integer(), nullable=True),
        sa.Column('is_payer', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('is_settled', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('settled_at', sa.DateTime(), nullable=True),
    )
    op.create_index('ix_split_participants_split_user', 'split_participants', ['split_id', 'user_id'], unique=True)


def downgrade() -> None:
    # Drop tables in reverse order of creation (respecting foreign key dependencies)
    op.drop_table('split_participants')
    op.drop_table('transaction_splits')
    op.drop_table('member_budgets')
    op.drop_table('goal_contributions')
    op.drop_table('transactions')
    op.drop_table('family_saving_goals')
    op.drop_table('family_budgets')
    op.drop_table('expense_targets')
    op.drop_table('budgets')
    op.drop_table('book_members')
    op.drop_table('book_invitations')
    op.drop_table('admin_logs')
    op.drop_table('oauth_providers')
    op.drop_table('email_bindings')
    op.drop_table('categories')
    op.drop_table('books')
    op.drop_table('backups')
    op.drop_table('admin_users')
    op.drop_table('admin_role_permissions')
    op.drop_table('accounts')
    op.drop_table('users')
    op.drop_table('upgrade_analytics')
    op.drop_table('app_versions')
    op.drop_table('admin_roles')
    op.drop_table('admin_permissions')

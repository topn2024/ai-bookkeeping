"""Create oauth_providers table

Revision ID: 0004
Revises: 0003
Create Date: 2024-12-28

Add support for third-party OAuth login (WeChat, Apple, Google).
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0004'
down_revision: Union[str, None] = '0003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create oauth_providers table."""
    op.create_table(
        'oauth_providers',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),

        # Provider identification
        sa.Column('provider', sa.String(20), nullable=False,
                  comment='OAuth provider name: wechat, apple, google'),
        sa.Column('provider_user_id', sa.String(200), nullable=False,
                  comment='Unique user ID from provider (openid/sub)'),

        # Provider user info (cached)
        sa.Column('provider_username', sa.String(100), nullable=True),
        sa.Column('provider_avatar', sa.String(500), nullable=True),
        sa.Column('provider_email', sa.String(100), nullable=True),
        sa.Column('provider_raw_data', postgresql.JSONB(), nullable=True,
                  comment='Complete user info JSON from provider'),

        # OAuth tokens
        sa.Column('access_token', sa.Text(), nullable=True,
                  comment='OAuth access token (encrypt in production)'),
        sa.Column('refresh_token', sa.Text(), nullable=True,
                  comment='OAuth refresh token (encrypt in production)'),
        sa.Column('token_expires_at', sa.DateTime(), nullable=True),

        # Metadata
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('last_login_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),

        # Foreign key
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),

        # Unique constraint: one provider account can only bind to one user
        sa.UniqueConstraint('provider', 'provider_user_id', name='uq_oauth_providers_provider_user'),
    )

    # Create indexes
    op.create_index('idx_oauth_providers_user_id', 'oauth_providers', ['user_id'])
    op.create_index('idx_oauth_providers_provider', 'oauth_providers', ['provider'])
    op.create_index('idx_oauth_providers_provider_user_id', 'oauth_providers', ['provider_user_id'])
    op.create_index('idx_oauth_providers_is_active', 'oauth_providers', ['is_active'])

    # Unique index: one user can only bind one account per provider
    op.create_index('idx_oauth_providers_user_provider', 'oauth_providers',
                    ['user_id', 'provider'], unique=True)

    # Create update trigger
    op.execute('''
        CREATE OR REPLACE FUNCTION update_oauth_providers_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    ''')

    op.execute('''
        CREATE TRIGGER trigger_oauth_providers_updated_at
            BEFORE UPDATE ON oauth_providers
            FOR EACH ROW
            EXECUTE FUNCTION update_oauth_providers_updated_at();
    ''')


def downgrade() -> None:
    """Drop oauth_providers table."""
    # Drop trigger
    op.execute('DROP TRIGGER IF EXISTS trigger_oauth_providers_updated_at ON oauth_providers')
    op.execute('DROP FUNCTION IF EXISTS update_oauth_providers_updated_at()')

    # Drop indexes
    op.drop_index('idx_oauth_providers_user_provider', table_name='oauth_providers')
    op.drop_index('idx_oauth_providers_is_active', table_name='oauth_providers')
    op.drop_index('idx_oauth_providers_provider_user_id', table_name='oauth_providers')
    op.drop_index('idx_oauth_providers_provider', table_name='oauth_providers')
    op.drop_index('idx_oauth_providers_user_id', table_name='oauth_providers')

    # Drop table
    op.drop_table('oauth_providers')

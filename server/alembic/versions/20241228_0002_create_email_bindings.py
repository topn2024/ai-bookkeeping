"""Create email_bindings table

Revision ID: 0002
Revises: 0001
Create Date: 2024-12-28

Add support for email binding to enable automatic bill parsing from email.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0002'
down_revision: Union[str, None] = '0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create email_bindings table."""
    op.create_table(
        'email_bindings',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('email', sa.String(100), nullable=False),
        sa.Column('email_type', sa.Integer(), nullable=False,
                  comment='1: Gmail, 2: Outlook, 3: QQ, 4: 163, 5: Custom IMAP'),

        # OAuth tokens
        sa.Column('access_token', sa.Text(), nullable=True),
        sa.Column('refresh_token', sa.Text(), nullable=True),
        sa.Column('token_expires_at', sa.DateTime(), nullable=True),

        # IMAP credentials
        sa.Column('imap_server', sa.String(100), nullable=True),
        sa.Column('imap_port', sa.Integer(), nullable=True, server_default='993'),
        sa.Column('imap_password', sa.Text(), nullable=True),

        # Sync status
        sa.Column('last_sync_at', sa.DateTime(), nullable=True),
        sa.Column('last_sync_message_id', sa.String(200), nullable=True),
        sa.Column('sync_error', sa.String(500), nullable=True),

        # Status
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),

        # Foreign key
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),

        # Unique constraint
        sa.UniqueConstraint('user_id', 'email', name='uq_email_bindings_user_email'),
    )

    # Create indexes
    op.create_index('idx_email_bindings_user_id', 'email_bindings', ['user_id'])
    op.create_index('idx_email_bindings_email', 'email_bindings', ['email'])
    op.create_index('idx_email_bindings_is_active', 'email_bindings', ['is_active'])

    # Create update trigger (PostgreSQL)
    op.execute('''
        CREATE OR REPLACE FUNCTION update_email_bindings_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    ''')

    op.execute('''
        CREATE TRIGGER trigger_email_bindings_updated_at
            BEFORE UPDATE ON email_bindings
            FOR EACH ROW
            EXECUTE FUNCTION update_email_bindings_updated_at();
    ''')


def downgrade() -> None:
    """Drop email_bindings table."""
    # Drop trigger first
    op.execute('DROP TRIGGER IF EXISTS trigger_email_bindings_updated_at ON email_bindings')
    op.execute('DROP FUNCTION IF EXISTS update_email_bindings_updated_at()')

    # Drop indexes
    op.drop_index('idx_email_bindings_is_active', table_name='email_bindings')
    op.drop_index('idx_email_bindings_email', table_name='email_bindings')
    op.drop_index('idx_email_bindings_user_id', table_name='email_bindings')

    # Drop table
    op.drop_table('email_bindings')

"""Create app_versions table

Revision ID: 0005
Revises: 0004
Create Date: 2024-12-30

Stores app version information for remote update functionality.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0005'
down_revision: Union[str, None] = '0004'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create app_versions table."""
    op.create_table(
        'app_versions',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text('gen_random_uuid()')),

        # Version info
        sa.Column('version_name', sa.String(20), nullable=False,
                  comment='e.g., "1.2.1"'),
        sa.Column('version_code', sa.Integer(), nullable=False,
                  comment='e.g., 18'),

        # Platform
        sa.Column('platform', sa.String(20), nullable=False, server_default='android'),

        # APK file info
        sa.Column('file_url', sa.String(500), nullable=True,
                  comment='MinIO URL'),
        sa.Column('file_size', sa.BigInteger(), nullable=True,
                  comment='File size in bytes'),
        sa.Column('file_md5', sa.String(32), nullable=True,
                  comment='MD5 checksum'),

        # Update info
        sa.Column('release_notes', sa.Text(), nullable=False,
                  comment='Release notes (markdown)'),
        sa.Column('release_notes_en', sa.Text(), nullable=True,
                  comment='English release notes'),

        # Update strategy
        sa.Column('is_force_update', sa.Boolean(), nullable=False, server_default='false',
                  comment='If true, users must update to continue using the app'),
        sa.Column('min_supported_version', sa.String(20), nullable=True,
                  comment='Versions below this will be forced to update'),

        # Release status: 0=draft, 1=published, 2=deprecated
        sa.Column('status', sa.Integer(), nullable=False, server_default='0',
                  comment='0=draft, 1=published, 2=deprecated'),
        sa.Column('published_at', sa.DateTime(), nullable=True),

        # Audit fields
        sa.Column('created_at', sa.DateTime(), nullable=False,
                  server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('updated_at', sa.DateTime(), nullable=False,
                  server_default=sa.text('CURRENT_TIMESTAMP')),
        sa.Column('created_by', sa.String(100), nullable=True),

        # Unique constraint
        sa.UniqueConstraint('version_name', 'version_code', 'platform',
                           name='uq_app_versions_version_platform'),
    )

    # Create indexes
    op.create_index('idx_app_versions_platform_status', 'app_versions',
                    ['platform', 'status'])
    op.create_index('idx_app_versions_version_code', 'app_versions',
                    ['version_code'], postgresql_ops={'version_code': 'DESC'})
    op.create_index('idx_app_versions_created_at', 'app_versions',
                    ['created_at'], postgresql_ops={'created_at': 'DESC'})


def downgrade() -> None:
    """Drop app_versions table."""
    # Drop indexes
    op.drop_index('idx_app_versions_created_at', table_name='app_versions')
    op.drop_index('idx_app_versions_version_code', table_name='app_versions')
    op.drop_index('idx_app_versions_platform_status', table_name='app_versions')

    # Drop table
    op.drop_table('app_versions')

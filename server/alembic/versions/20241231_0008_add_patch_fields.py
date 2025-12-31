"""Add patch fields for incremental updates

Revision ID: 0008
Revises: 0007
Create Date: 2024-12-31

Add fields to support incremental (patch) updates for app versions.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0008'
down_revision: Union[str, None] = '0007'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add patch file columns to app_versions table."""
    # Base version for patch
    op.add_column(
        'app_versions',
        sa.Column('patch_from_version', sa.String(20), nullable=True,
                  comment='Base version for patch (e.g., 1.2.0)')
    )
    op.add_column(
        'app_versions',
        sa.Column('patch_from_code', sa.Integer(), nullable=True,
                  comment='Base version code for patch')
    )

    # Patch file info
    op.add_column(
        'app_versions',
        sa.Column('patch_file_url', sa.String(500), nullable=True,
                  comment='Patch file URL')
    )
    op.add_column(
        'app_versions',
        sa.Column('patch_file_size', sa.BigInteger(), nullable=True,
                  comment='Patch file size in bytes')
    )
    op.add_column(
        'app_versions',
        sa.Column('patch_file_md5', sa.String(32), nullable=True,
                  comment='Patch file MD5 checksum')
    )

    # Create index for patch lookup
    op.create_index(
        'ix_app_versions_patch_from',
        'app_versions',
        ['platform', 'patch_from_code']
    )


def downgrade() -> None:
    """Remove patch file columns from app_versions table."""
    op.drop_index('ix_app_versions_patch_from', 'app_versions')
    op.drop_column('app_versions', 'patch_file_md5')
    op.drop_column('app_versions', 'patch_file_size')
    op.drop_column('app_versions', 'patch_file_url')
    op.drop_column('app_versions', 'patch_from_code')
    op.drop_column('app_versions', 'patch_from_version')

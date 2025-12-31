"""Add rollout fields to app_versions

Revision ID: 0006
Revises: 0005
Create Date: 2024-12-31

Add gradual rollout support for app versions.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0006'
down_revision: Union[str, None] = '0005'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add rollout columns to app_versions table."""
    # Add rollout_percentage column (default 100 = full rollout)
    op.add_column(
        'app_versions',
        sa.Column('rollout_percentage', sa.Integer(), nullable=False, server_default='100',
                  comment='Percentage of users who see this update (0-100)')
    )

    # Add rollout_start_date column
    op.add_column(
        'app_versions',
        sa.Column('rollout_start_date', sa.DateTime(), nullable=True,
                  comment='When gradual rollout started')
    )

    # Add check constraint for percentage range
    op.create_check_constraint(
        'ck_app_versions_rollout_percentage',
        'app_versions',
        'rollout_percentage >= 0 AND rollout_percentage <= 100'
    )


def downgrade() -> None:
    """Remove rollout columns from app_versions table."""
    # Drop check constraint
    op.drop_constraint('ck_app_versions_rollout_percentage', 'app_versions', type_='check')

    # Drop columns
    op.drop_column('app_versions', 'rollout_start_date')
    op.drop_column('app_versions', 'rollout_percentage')

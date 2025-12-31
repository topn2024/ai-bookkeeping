"""Add upgrade_analytics table

Revision ID: 0007
Revises: 0006
Create Date: 2024-12-31

Store upgrade analytics events from client apps.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0007'
down_revision: Union[str, None] = '0006'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create upgrade_analytics table."""
    op.create_table(
        'upgrade_analytics',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('event_type', sa.String(50), nullable=False,
                  comment='Event type: check_update, download_start, etc.'),
        sa.Column('platform', sa.String(20), nullable=False, server_default='android',
                  comment='Platform: android/ios'),
        sa.Column('from_version', sa.String(20), nullable=False,
                  comment='Version before upgrade'),
        sa.Column('to_version', sa.String(20), nullable=True,
                  comment='Target version for upgrade'),
        sa.Column('from_build', sa.Integer(), nullable=True,
                  comment='Build number before upgrade'),
        sa.Column('to_build', sa.Integer(), nullable=True,
                  comment='Target build number'),
        sa.Column('download_progress', sa.Integer(), nullable=True,
                  comment='Download progress percentage (0-100)'),
        sa.Column('download_size', sa.Integer(), nullable=True,
                  comment='Total download size in bytes'),
        sa.Column('download_duration_ms', sa.Integer(), nullable=True,
                  comment='Download duration in milliseconds'),
        sa.Column('error_message', sa.Text(), nullable=True,
                  comment='Error message if failed'),
        sa.Column('error_code', sa.String(50), nullable=True,
                  comment='Error code for categorization'),
        sa.Column('device_id', sa.String(100), nullable=True,
                  comment='Unique device identifier'),
        sa.Column('device_model', sa.String(100), nullable=True,
                  comment='Device model name'),
        sa.Column('extra_data', sa.Text(), nullable=True,
                  comment='Additional JSON data'),
        sa.Column('event_time', sa.DateTime(), nullable=False,
                  comment='When the event occurred on client'),
        sa.Column('created_at', sa.DateTime(), nullable=False,
                  server_default=sa.text('CURRENT_TIMESTAMP'),
                  comment='When the event was recorded on server'),
        sa.PrimaryKeyConstraint('id')
    )

    # Create indexes
    op.create_index('ix_upgrade_analytics_event_type', 'upgrade_analytics', ['event_type'])
    op.create_index('ix_upgrade_analytics_device_id', 'upgrade_analytics', ['device_id'])
    op.create_index('ix_upgrade_analytics_event_time', 'upgrade_analytics', ['event_time'])
    op.create_index('ix_upgrade_analytics_version', 'upgrade_analytics', ['to_version', 'event_type'])
    op.create_index('ix_upgrade_analytics_platform_event', 'upgrade_analytics', ['platform', 'event_type'])


def downgrade() -> None:
    """Drop upgrade_analytics table."""
    op.drop_index('ix_upgrade_analytics_platform_event', 'upgrade_analytics')
    op.drop_index('ix_upgrade_analytics_version', 'upgrade_analytics')
    op.drop_index('ix_upgrade_analytics_event_time', 'upgrade_analytics')
    op.drop_index('ix_upgrade_analytics_device_id', 'upgrade_analytics')
    op.drop_index('ix_upgrade_analytics_event_type', 'upgrade_analytics')
    op.drop_table('upgrade_analytics')

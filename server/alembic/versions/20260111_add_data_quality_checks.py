"""添加数据质量检查表

Revision ID: 20260111_data_quality
Revises: 20260109_companion_message_library
Create Date: 2026-01-11

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260111_data_quality'
down_revision: Union[str, None] = '20260109_companion_message_library'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """创建data_quality_checks表"""
    op.create_table(
        'data_quality_checks',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('check_time', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),
        sa.Column('check_type', sa.String(50), nullable=False, comment='检查类型: null_check, range_check, consistency_check'),
        sa.Column('target_table', sa.String(100), nullable=False, comment='目标表名'),
        sa.Column('target_column', sa.String(100), nullable=True, comment='目标字段名'),
        sa.Column('severity', sa.String(20), nullable=False, comment='严重程度: low, medium, high, critical'),

        # 检查结果
        sa.Column('total_records', sa.Integer(), nullable=False, comment='总记录数'),
        sa.Column('affected_records', sa.Integer(), nullable=False, comment='受影响记录数'),
        sa.Column('issue_details', postgresql.JSONB(), nullable=True, comment='问题详情'),

        # 状态管理
        sa.Column('status', sa.String(20), nullable=False, server_default='detected', comment='状态: detected, investigating, fixed, ignored'),
        sa.Column('assigned_to', sa.String(100), nullable=True, comment='分配给'),
        sa.Column('resolved_at', sa.DateTime(), nullable=True, comment='解决时间'),
        sa.Column('resolution_notes', sa.Text(), nullable=True, comment='解决说明'),

        # 约束
        sa.CheckConstraint(
            "check_type IN ('null_check', 'range_check', 'consistency_check')",
            name='ck_data_quality_checks_type'
        ),
        sa.CheckConstraint(
            "severity IN ('low', 'medium', 'high', 'critical')",
            name='ck_data_quality_checks_severity'
        ),
        sa.CheckConstraint(
            "status IN ('detected', 'investigating', 'fixed', 'ignored')",
            name='ck_data_quality_checks_status'
        ),
    )

    # 创建索引
    op.create_index('idx_data_quality_checks_check_time', 'data_quality_checks', ['check_time'])
    op.create_index('idx_data_quality_checks_status', 'data_quality_checks', ['status'])
    op.create_index('idx_data_quality_checks_severity', 'data_quality_checks', ['severity'])
    op.create_index('idx_data_quality_checks_target', 'data_quality_checks', ['target_table', 'target_column'])


def downgrade() -> None:
    """删除data_quality_checks表"""
    op.drop_index('idx_data_quality_checks_target', table_name='data_quality_checks')
    op.drop_index('idx_data_quality_checks_severity', table_name='data_quality_checks')
    op.drop_index('idx_data_quality_checks_status', table_name='data_quality_checks')
    op.drop_index('idx_data_quality_checks_check_time', table_name='data_quality_checks')
    op.drop_table('data_quality_checks')

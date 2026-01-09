"""Add companion message library for AI-generated greetings

Revision ID: 20260109_companion_msg
Revises: 20260109_v2_initial
Create Date: 2026-01-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260109_companion_msg'
down_revision: Union[str, None] = '20260109_v2_initial'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ==================== Companion Message Library ====================
    op.create_table(
        'companion_message_library',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('scene_type', sa.String(50), nullable=False, index=True),
        sa.Column('emotion_type', sa.String(50), nullable=False, index=True),
        sa.Column('time_of_day', sa.String(20), nullable=True, index=True),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('language', sa.String(10), server_default='zh_CN', index=True),
        sa.Column('generation_method', sa.String(20), server_default='ai'),  # 'ai' or 'manual'
        sa.Column('quality_score', sa.Float(), nullable=True),  # AI评分或用户反馈评分
        sa.Column('usage_count', sa.Integer(), server_default='0'),  # 使用次数
        sa.Column('positive_feedback', sa.Integer(), server_default='0'),  # 正面反馈数
        sa.Column('negative_feedback', sa.Integer(), server_default='0'),  # 负面反馈数
        sa.Column('is_active', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('last_used_at', sa.DateTime(), nullable=True),
    )

    # 创建复合索引以提高查询效率
    op.create_index(
        'idx_companion_msg_scene_emotion',
        'companion_message_library',
        ['scene_type', 'emotion_type', 'language', 'is_active']
    )

    # ==================== Companion Message Generation Log ====================
    op.create_table(
        'companion_message_generation_log',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('batch_id', sa.String(50), nullable=False, index=True),
        sa.Column('scene_type', sa.String(50), nullable=False),
        sa.Column('emotion_type', sa.String(50), nullable=False),
        sa.Column('generated_count', sa.Integer(), nullable=False),
        sa.Column('success_count', sa.Integer(), nullable=False),
        sa.Column('failed_count', sa.Integer(), nullable=False),
        sa.Column('generation_time_ms', sa.Integer(), nullable=True),
        sa.Column('model_name', sa.String(100), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    # ==================== Companion Message User Feedback ====================
    op.create_table(
        'companion_message_feedback',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('message_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('companion_message_library.id', ondelete='CASCADE'), nullable=False),
        sa.Column('feedback_type', sa.String(20), nullable=False),  # 'like', 'dislike', 'report'
        sa.Column('feedback_reason', sa.String(100), nullable=True),  # 反馈原因
        sa.Column('created_at', sa.DateTime(), nullable=False),
    )

    op.create_index(
        'idx_companion_feedback_user',
        'companion_message_feedback',
        ['user_id', 'created_at']
    )


def downgrade() -> None:
    op.drop_table('companion_message_feedback')
    op.drop_table('companion_message_generation_log')
    op.drop_index('idx_companion_msg_scene_emotion', table_name='companion_message_library')
    op.drop_table('companion_message_library')

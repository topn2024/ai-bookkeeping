"""添加邮箱验证字段

Revision ID: 20260122_email_verification
Revises: 20260111_data_quality
Create Date: 2026-01-22

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '20260122_email_verification'
down_revision: Union[str, None] = '20260111_data_quality'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """添加邮箱验证相关字段到users表"""
    op.add_column('users', sa.Column('email_verified', sa.Boolean(), server_default='false', nullable=False))
    op.add_column('users', sa.Column('email_verified_at', sa.DateTime(), nullable=True))


def downgrade() -> None:
    """删除邮箱验证相关字段"""
    op.drop_column('users', 'email_verified_at')
    op.drop_column('users', 'email_verified')

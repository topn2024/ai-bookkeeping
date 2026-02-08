"""为同步所需模型添加 updated_at 字段

修复 C-02: 8 个模型缺少 updated_at 导致 Pull 同步崩溃
修复 FamilyBudget/MemberBudget 的 updated_at 无默认值

Revision ID: 20260208_add_updated_at
Revises: 20260122_email_verification
Create Date: 2026-02-08

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '20260208_add_updated_at'
down_revision: Union[str, None] = '20260122_email_verification'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 有 created_at 的表：用 created_at 回填
    tables_with_created_at = [
        'categories',
        'family_saving_goals',
        'goal_contributions',
        'transaction_splits',
        'consumption_records',
        'money_age_snapshots',
    ]
    for table in tables_with_created_at:
        op.add_column(table, sa.Column('updated_at', sa.DateTime(), nullable=True))
        op.execute(
            f"UPDATE {table} SET updated_at = created_at WHERE updated_at IS NULL AND created_at IS NOT NULL"
        )
        op.execute(
            f"UPDATE {table} SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
        )
        op.alter_column(table, 'updated_at', nullable=False)

    # book_members: 没有 created_at，用 joined_at 回填
    op.add_column('book_members', sa.Column('updated_at', sa.DateTime(), nullable=True))
    op.execute(
        "UPDATE book_members SET updated_at = joined_at WHERE updated_at IS NULL AND joined_at IS NOT NULL"
    )
    op.execute(
        "UPDATE book_members SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
    )
    op.alter_column('book_members', 'updated_at', nullable=False)

    # split_participants: 没有 created_at，直接用 CURRENT_TIMESTAMP
    op.add_column('split_participants', sa.Column('updated_at', sa.DateTime(), nullable=True))
    op.execute(
        "UPDATE split_participants SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
    )
    op.alter_column('split_participants', 'updated_at', nullable=False)

    # 修复 family_budgets 和 member_budgets 的 updated_at（已存在但 nullable 且无默认值）
    for table in ['family_budgets', 'member_budgets']:
        op.execute(
            f"UPDATE {table} SET updated_at = created_at WHERE updated_at IS NULL AND created_at IS NOT NULL"
        )
        op.execute(
            f"UPDATE {table} SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
        )
        op.alter_column(table, 'updated_at', nullable=False)


def downgrade() -> None:
    # 移除新增的 updated_at 列
    tables_to_remove = [
        'categories',
        'book_members',
        'family_saving_goals',
        'goal_contributions',
        'transaction_splits',
        'split_participants',
        'consumption_records',
        'money_age_snapshots',
    ]
    for table in tables_to_remove:
        op.drop_column(table, 'updated_at')

    # 恢复 family_budgets 和 member_budgets 的 updated_at 为 nullable
    for table in ['family_budgets', 'member_budgets']:
        op.alter_column(table, 'updated_at', nullable=True)

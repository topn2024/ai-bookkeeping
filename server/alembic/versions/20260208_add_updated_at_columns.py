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
    # 新增 updated_at 列的表（8个模型）
    tables_to_add = [
        'categories',
        'book_members',
        'family_saving_goals',
        'goal_contributions',
        'transaction_splits',
        'split_participants',
        'consumption_records',
        'money_age_snapshots',
    ]
    for table in tables_to_add:
        op.add_column(table, sa.Column('updated_at', sa.DateTime(), nullable=True))
        # 用 created_at 回填已有记录（如果有 created_at）
        op.execute(
            f"UPDATE {table} SET updated_at = created_at WHERE updated_at IS NULL AND created_at IS NOT NULL"
        )
        # book_members 没有 created_at，用 joined_at
        if table == 'book_members':
            op.execute(
                "UPDATE book_members SET updated_at = joined_at WHERE updated_at IS NULL AND joined_at IS NOT NULL"
            )
        # split_participants 没有 created_at，用 CURRENT_TIMESTAMP
        if table == 'split_participants':
            op.execute(
                "UPDATE split_participants SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
            )
        # 确保所有记录都有值
        op.execute(
            f"UPDATE {table} SET updated_at = CURRENT_TIMESTAMP WHERE updated_at IS NULL"
        )
        op.alter_column(table, 'updated_at', nullable=False)

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

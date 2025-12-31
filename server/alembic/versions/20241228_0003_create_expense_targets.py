"""Create expense_targets table

Revision ID: 0003
Revises: 0002
Create Date: 2024-12-28

Add support for monthly expense targets to control spending.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '0003'
down_revision: Union[str, None] = '0002'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create expense_targets table."""
    op.create_table(
        'expense_targets',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text('gen_random_uuid()')),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('book_id', postgresql.UUID(as_uuid=True), nullable=False),

        # Target definition
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('description', sa.String(500), nullable=True),
        sa.Column('max_amount', sa.Numeric(15, 2), nullable=False,
                  comment='Monthly spending limit'),

        # Category filter (NULL = total spending)
        sa.Column('category_id', postgresql.UUID(as_uuid=True), nullable=True,
                  comment='NULL means total spending across all categories'),

        # Time period
        sa.Column('year', sa.Integer(), nullable=False),
        sa.Column('month', sa.Integer(), nullable=False),

        # Display settings
        sa.Column('icon_code', sa.Integer(), nullable=True, server_default='59604'),
        sa.Column('color_value', sa.Integer(), nullable=True, server_default='4283215696'),

        # Alert settings
        sa.Column('alert_threshold', sa.Integer(), nullable=True, server_default='80',
                  comment='Percentage at which to alert user (default 80%)'),
        sa.Column('enable_notifications', sa.Boolean(), nullable=False, server_default='true'),

        # Status
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),
        sa.Column('updated_at', sa.DateTime(), nullable=False, server_default=sa.text('NOW()')),

        # Foreign keys
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['book_id'], ['books.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['category_id'], ['categories.id'], ondelete='SET NULL'),

        # Unique constraint
        sa.UniqueConstraint('user_id', 'book_id', 'category_id', 'year', 'month',
                           name='uq_expense_targets_user_book_category_period'),

        # Check constraints
        sa.CheckConstraint('month >= 1 AND month <= 12', name='ck_expense_targets_month'),
        sa.CheckConstraint('alert_threshold >= 0 AND alert_threshold <= 100',
                          name='ck_expense_targets_alert_threshold'),
    )

    # Create indexes
    op.create_index('idx_expense_targets_user_id', 'expense_targets', ['user_id'])
    op.create_index('idx_expense_targets_book_id', 'expense_targets', ['book_id'])
    op.create_index('idx_expense_targets_category_id', 'expense_targets', ['category_id'])
    op.create_index('idx_expense_targets_period', 'expense_targets', ['year', 'month'])
    op.create_index('idx_expense_targets_is_active', 'expense_targets', ['is_active'])

    # Create update trigger
    op.execute('''
        CREATE OR REPLACE FUNCTION update_expense_targets_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
    ''')

    op.execute('''
        CREATE TRIGGER trigger_expense_targets_updated_at
            BEFORE UPDATE ON expense_targets
            FOR EACH ROW
            EXECUTE FUNCTION update_expense_targets_updated_at();
    ''')


def downgrade() -> None:
    """Drop expense_targets table."""
    # Drop trigger
    op.execute('DROP TRIGGER IF EXISTS trigger_expense_targets_updated_at ON expense_targets')
    op.execute('DROP FUNCTION IF EXISTS update_expense_targets_updated_at()')

    # Drop indexes
    op.drop_index('idx_expense_targets_is_active', table_name='expense_targets')
    op.drop_index('idx_expense_targets_period', table_name='expense_targets')
    op.drop_index('idx_expense_targets_category_id', table_name='expense_targets')
    op.drop_index('idx_expense_targets_book_id', table_name='expense_targets')
    op.drop_index('idx_expense_targets_user_id', table_name='expense_targets')

    # Drop table
    op.drop_table('expense_targets')

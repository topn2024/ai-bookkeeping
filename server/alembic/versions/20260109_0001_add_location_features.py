"""Add location features - Chapter 14

Revision ID: 20260109_0001
Revises: 20260108_0001
Create Date: 2026-01-09

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20260109_0001'
down_revision: Union[str, None] = '20260108_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add structured location fields to transactions table
    op.add_column('transactions', sa.Column('location_latitude', sa.Numeric(10, 7), nullable=True))
    op.add_column('transactions', sa.Column('location_longitude', sa.Numeric(10, 7), nullable=True))
    op.add_column('transactions', sa.Column('location_place_name', sa.String(200), nullable=True))
    op.add_column('transactions', sa.Column('location_address', sa.String(500), nullable=True))
    op.add_column('transactions', sa.Column('location_city', sa.String(100), nullable=True))
    op.add_column('transactions', sa.Column('location_district', sa.String(100), nullable=True))
    op.add_column('transactions', sa.Column('location_type', sa.Integer(), nullable=True))
    op.add_column('transactions', sa.Column('location_poi_id', sa.String(100), nullable=True))

    # Create geo_fences table
    op.create_table(
        'geo_fences',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('center_latitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('center_longitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('radius_meters', sa.Float(), nullable=False, server_default='100'),
        sa.Column('place_name', sa.String(200), nullable=True),
        sa.Column('action', sa.Integer(), nullable=False, server_default='4'),
        sa.Column('linked_category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id'), nullable=True),
        sa.Column('linked_vault_id', sa.String(100), nullable=True),
        sa.Column('budget_limit', sa.Numeric(15, 2), nullable=True),
        sa.Column('is_enabled', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_geo_fences_user_id', 'geo_fences', ['user_id'])

    # Create frequent_locations table
    op.create_table(
        'frequent_locations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('latitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('longitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('place_name', sa.String(200), nullable=True),
        sa.Column('address', sa.String(500), nullable=True),
        sa.Column('city', sa.String(100), nullable=True),
        sa.Column('district', sa.String(100), nullable=True),
        sa.Column('location_type', sa.Integer(), nullable=True),
        sa.Column('poi_id', sa.String(100), nullable=True),
        sa.Column('visit_count', sa.Integer(), server_default='1'),
        sa.Column('total_spent', sa.Numeric(15, 2), server_default='0'),
        sa.Column('default_category_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('categories.id'), nullable=True),
        sa.Column('default_vault_id', sa.String(100), nullable=True),
        sa.Column('last_visit_at', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_frequent_locations_user_id', 'frequent_locations', ['user_id'])
    op.create_index('ix_frequent_locations_coords', 'frequent_locations', ['latitude', 'longitude'])

    # Create user_home_locations table
    op.create_table(
        'user_home_locations',
        sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('location_role', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('latitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('longitude', sa.Numeric(10, 7), nullable=False),
        sa.Column('city', sa.String(100), nullable=True),
        sa.Column('radius_meters', sa.Float(), server_default='5000'),
        sa.Column('is_primary', sa.Boolean(), server_default='false'),
        sa.Column('is_enabled', sa.Boolean(), server_default='true'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
    )
    op.create_index('ix_user_home_locations_user_id', 'user_home_locations', ['user_id'])


def downgrade() -> None:
    # Drop tables
    op.drop_index('ix_user_home_locations_user_id', table_name='user_home_locations')
    op.drop_table('user_home_locations')

    op.drop_index('ix_frequent_locations_coords', table_name='frequent_locations')
    op.drop_index('ix_frequent_locations_user_id', table_name='frequent_locations')
    op.drop_table('frequent_locations')

    op.drop_index('ix_geo_fences_user_id', table_name='geo_fences')
    op.drop_table('geo_fences')

    # Drop columns from transactions
    op.drop_column('transactions', 'location_poi_id')
    op.drop_column('transactions', 'location_type')
    op.drop_column('transactions', 'location_district')
    op.drop_column('transactions', 'location_city')
    op.drop_column('transactions', 'location_address')
    op.drop_column('transactions', 'location_place_name')
    op.drop_column('transactions', 'location_longitude')
    op.drop_column('transactions', 'location_latitude')

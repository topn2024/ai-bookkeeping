-- Migration: Create expense_targets table
-- Description: Add support for monthly expense targets to control spending
-- Created: 2025-12-28

-- Create expense_targets table
CREATE TABLE IF NOT EXISTS expense_targets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,

    -- Target definition
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    max_amount DECIMAL(15, 2) NOT NULL,  -- Monthly spending limit

    -- Optional category filter (NULL = total spending)
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,

    -- Time period
    year INT NOT NULL,
    month INT NOT NULL CHECK (month >= 1 AND month <= 12),

    -- Display settings
    icon_code INT DEFAULT 59604,  -- Material Icons 'savings' (0xe8d4)
    color_value INT DEFAULT 4283215696,  -- Green (0xFF4CAF50)

    -- Alert settings
    alert_threshold INT DEFAULT 80 CHECK (alert_threshold >= 0 AND alert_threshold <= 100),
    enable_notifications BOOLEAN DEFAULT TRUE,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Prevent duplicate targets for same period and category
    UNIQUE(user_id, book_id, category_id, year, month)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_expense_targets_user_id ON expense_targets(user_id);
CREATE INDEX IF NOT EXISTS idx_expense_targets_book_id ON expense_targets(book_id);
CREATE INDEX IF NOT EXISTS idx_expense_targets_category_id ON expense_targets(category_id);
CREATE INDEX IF NOT EXISTS idx_expense_targets_period ON expense_targets(year, month);
CREATE INDEX IF NOT EXISTS idx_expense_targets_is_active ON expense_targets(is_active);

-- Add comments
COMMENT ON TABLE expense_targets IS 'Monthly expense targets for controlling spending';
COMMENT ON COLUMN expense_targets.max_amount IS 'Maximum spending limit for the month';
COMMENT ON COLUMN expense_targets.category_id IS 'NULL means total spending across all categories';
COMMENT ON COLUMN expense_targets.alert_threshold IS 'Percentage at which to alert user (default 80%)';

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_expense_targets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_expense_targets_updated_at
    BEFORE UPDATE ON expense_targets
    FOR EACH ROW
    EXECUTE FUNCTION update_expense_targets_updated_at();

-- Migration: Create email_bindings table
-- Description: Add support for email binding to enable automatic bill parsing from email
-- Created: 2025-12-28

-- Create email_bindings table
CREATE TABLE IF NOT EXISTS email_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    email VARCHAR(100) NOT NULL,
    email_type INT NOT NULL,  -- 1: Gmail, 2: Outlook, 3: QQ, 4: 163, 5: IMAP

    -- OAuth tokens (for Gmail/Outlook)
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,

    -- IMAP credentials (for QQ/163/custom IMAP)
    imap_server VARCHAR(100),
    imap_port INT DEFAULT 993,
    imap_password TEXT,  -- Should be encrypted

    -- Sync status
    last_sync_at TIMESTAMP,
    last_sync_message_id VARCHAR(200),
    sync_error VARCHAR(500),

    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Prevent duplicate email bindings per user
    UNIQUE(user_id, email)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_email_bindings_user_id ON email_bindings(user_id);
CREATE INDEX IF NOT EXISTS idx_email_bindings_email ON email_bindings(email);
CREATE INDEX IF NOT EXISTS idx_email_bindings_is_active ON email_bindings(is_active);

-- Add comment for email_type values
COMMENT ON COLUMN email_bindings.email_type IS '1: Gmail, 2: Outlook, 3: QQ, 4: 163, 5: Custom IMAP';

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_email_bindings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_email_bindings_updated_at
    BEFORE UPDATE ON email_bindings
    FOR EACH ROW
    EXECUTE FUNCTION update_email_bindings_updated_at();

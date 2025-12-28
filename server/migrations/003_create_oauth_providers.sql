-- Migration: Create oauth_providers table
-- Description: Add support for third-party OAuth login (WeChat, Apple, Google)
-- Created: 2025-12-28

-- Create oauth_providers table
CREATE TABLE IF NOT EXISTS oauth_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Provider identification
    provider VARCHAR(20) NOT NULL,  -- wechat, apple, google
    provider_user_id VARCHAR(200) NOT NULL,  -- openid / sub / user_id

    -- Provider user info (cached)
    provider_username VARCHAR(100),
    provider_avatar VARCHAR(500),
    provider_email VARCHAR(100),
    provider_raw_data JSONB,

    -- OAuth tokens (should be encrypted in production)
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMP,

    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    -- Unique constraint: one provider account can only bind to one user
    UNIQUE(provider, provider_user_id)
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_oauth_providers_user_id ON oauth_providers(user_id);
CREATE INDEX IF NOT EXISTS idx_oauth_providers_provider ON oauth_providers(provider);
CREATE INDEX IF NOT EXISTS idx_oauth_providers_provider_user_id ON oauth_providers(provider_user_id);
CREATE INDEX IF NOT EXISTS idx_oauth_providers_is_active ON oauth_providers(is_active);

-- Unique index: one user can only bind one account per provider
CREATE UNIQUE INDEX IF NOT EXISTS idx_oauth_providers_user_provider
    ON oauth_providers(user_id, provider);

-- Add comments
COMMENT ON TABLE oauth_providers IS 'OAuth provider bindings for third-party login';
COMMENT ON COLUMN oauth_providers.provider IS 'OAuth provider name: wechat, apple, google';
COMMENT ON COLUMN oauth_providers.provider_user_id IS 'Unique user ID from provider (openid/sub)';
COMMENT ON COLUMN oauth_providers.provider_raw_data IS 'Complete user info JSON from provider';
COMMENT ON COLUMN oauth_providers.access_token IS 'OAuth access token (encrypt in production)';
COMMENT ON COLUMN oauth_providers.refresh_token IS 'OAuth refresh token (encrypt in production)';

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_oauth_providers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_oauth_providers_updated_at
    BEFORE UPDATE ON oauth_providers
    FOR EACH ROW
    EXECUTE FUNCTION update_oauth_providers_updated_at();

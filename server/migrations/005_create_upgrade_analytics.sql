-- Migration: Create upgrade_analytics table for tracking app upgrade events
-- Date: 2024-12-31
-- Description: Stores analytics events from client apps to track upgrade behavior

-- Create upgrade_analytics table
CREATE TABLE IF NOT EXISTS upgrade_analytics (
    id SERIAL PRIMARY KEY,

    -- Event identification
    event_type VARCHAR(50) NOT NULL,        -- Event type: check_update, download_start, etc.
    platform VARCHAR(20) NOT NULL DEFAULT 'android',

    -- Version info
    from_version VARCHAR(20) NOT NULL,      -- Version before upgrade
    to_version VARCHAR(20),                 -- Target version for upgrade
    from_build INTEGER,                     -- Build number before upgrade
    to_build INTEGER,                       -- Target build number

    -- Download metrics
    download_progress INTEGER,              -- Download progress percentage (0-100)
    download_size INTEGER,                  -- Total download size in bytes
    download_duration_ms INTEGER,           -- Download duration in milliseconds

    -- Error info
    error_message TEXT,                     -- Error message if failed
    error_code VARCHAR(50),                 -- Error code for categorization

    -- Device info
    device_id VARCHAR(100),                 -- Unique device identifier
    device_model VARCHAR(100),              -- Device model name

    -- Extra data (JSON)
    extra_data TEXT,                        -- Additional JSON data

    -- Timestamps
    event_time TIMESTAMP NOT NULL,          -- When the event occurred on client
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- When the event was recorded on server
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS ix_upgrade_analytics_event_type
    ON upgrade_analytics (event_type);

CREATE INDEX IF NOT EXISTS ix_upgrade_analytics_device_id
    ON upgrade_analytics (device_id);

CREATE INDEX IF NOT EXISTS ix_upgrade_analytics_event_time
    ON upgrade_analytics (event_time);

CREATE INDEX IF NOT EXISTS ix_upgrade_analytics_version
    ON upgrade_analytics (to_version, event_type);

CREATE INDEX IF NOT EXISTS ix_upgrade_analytics_platform_event
    ON upgrade_analytics (platform, event_type);

-- Add comments
COMMENT ON TABLE upgrade_analytics IS 'Stores upgrade analytics events from client apps';
COMMENT ON COLUMN upgrade_analytics.event_type IS 'Event type: check_update, download_start, download_complete, install_success, etc.';
COMMENT ON COLUMN upgrade_analytics.download_duration_ms IS 'Download duration in milliseconds';

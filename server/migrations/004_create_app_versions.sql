-- Migration: Create app_versions table for app upgrade management
-- Date: 2024-12-30
-- Updated: 2024-12-31 (added rollout and patch fields)
-- Description: Stores app version information for remote update functionality

-- Create app_versions table
CREATE TABLE IF NOT EXISTS app_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Version info
    version_name VARCHAR(20) NOT NULL,      -- e.g., "1.2.1"
    version_code INTEGER NOT NULL,          -- e.g., 18

    -- Platform
    platform VARCHAR(20) NOT NULL DEFAULT 'android',

    -- APK file info (full package)
    file_url VARCHAR(500),                  -- MinIO URL
    file_size BIGINT,                       -- File size in bytes
    file_md5 VARCHAR(32),                   -- MD5 checksum

    -- Patch file info (incremental update)
    patch_from_version VARCHAR(20),         -- Base version for patch
    patch_from_code INTEGER,                -- Base version code for patch
    patch_file_url VARCHAR(500),            -- Patch file URL
    patch_file_size BIGINT,                 -- Patch file size in bytes
    patch_file_md5 VARCHAR(32),             -- Patch file MD5 checksum

    -- Update info
    release_notes TEXT NOT NULL,            -- Release notes (markdown)
    release_notes_en TEXT,                  -- English release notes

    -- Update strategy
    is_force_update BOOLEAN DEFAULT FALSE,  -- Force update flag
    min_supported_version VARCHAR(20),      -- Minimum supported version

    -- Gradual rollout
    rollout_percentage INTEGER DEFAULT 100, -- 0-100, percentage of users
    rollout_start_date TIMESTAMP,           -- When gradual rollout started

    -- Release status: 0=draft, 1=published, 2=deprecated
    status INTEGER DEFAULT 0,
    published_at TIMESTAMP,

    -- Audit fields
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),

    -- Constraints
    CONSTRAINT unique_version_platform UNIQUE (version_name, version_code, platform)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_app_versions_platform_status
    ON app_versions (platform, status);

CREATE INDEX IF NOT EXISTS idx_app_versions_version_code
    ON app_versions (version_code DESC);

CREATE INDEX IF NOT EXISTS idx_app_versions_created_at
    ON app_versions (created_at DESC);

-- Add comment
COMMENT ON TABLE app_versions IS 'APP version management for remote updates';
COMMENT ON COLUMN app_versions.status IS '0=draft, 1=published, 2=deprecated';
COMMENT ON COLUMN app_versions.is_force_update IS 'If true, users must update to continue using the app';
COMMENT ON COLUMN app_versions.min_supported_version IS 'Versions below this will be forced to update';

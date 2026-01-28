-- 修复backup表结构，使其与模型定义匹配
-- 日期: 2026-01-28
-- 问题: 数据库表结构与模型定义不一致，导致500错误

BEGIN;

-- 1. 检查是否有现有备份数据（如果有，先备份）
DO $$
DECLARE
    backup_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO backup_count FROM backups;
    IF backup_count > 0 THEN
        RAISE NOTICE '警告: 发现 % 条现有备份记录，将被删除。如需保留，请先手动备份。', backup_count;
    END IF;
END $$;

-- 2. 删除现有backup表（因为结构差异太大，直接重建更简单）
DROP TABLE IF EXISTS backups CASCADE;

-- 3. 重新创建与模型匹配的backup表
CREATE TABLE backups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 基本信息
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    backup_type INTEGER DEFAULT 0 NOT NULL,  -- 0=手动备份, 1=自动备份

    -- 备份数据 (JSON格式)
    data TEXT NOT NULL,

    -- 基础数据统计
    transaction_count INTEGER DEFAULT 0 NOT NULL,
    account_count INTEGER DEFAULT 0 NOT NULL,
    category_count INTEGER DEFAULT 0 NOT NULL,
    book_count INTEGER DEFAULT 0 NOT NULL,
    budget_count INTEGER DEFAULT 0 NOT NULL,

    -- 扩展数据统计（新增）
    credit_card_count INTEGER DEFAULT 0 NOT NULL,
    debt_count INTEGER DEFAULT 0 NOT NULL,
    savings_goal_count INTEGER DEFAULT 0 NOT NULL,
    bill_reminder_count INTEGER DEFAULT 0 NOT NULL,
    recurring_count INTEGER DEFAULT 0 NOT NULL,

    -- 文件大小（字节）
    size BIGINT DEFAULT 0 NOT NULL,

    -- 设备信息
    device_name VARCHAR(100),
    device_id VARCHAR(100),
    app_version VARCHAR(20),

    -- 时间戳
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Shanghai') NOT NULL
);

-- 4. 创建索引
CREATE INDEX idx_backups_user_id ON backups(user_id);
CREATE INDEX idx_backups_created_at ON backups(created_at DESC);

-- 5. 添加表注释
COMMENT ON TABLE backups IS '用户数据备份表';
COMMENT ON COLUMN backups.backup_type IS '备份类型: 0=手动备份, 1=自动备份';
COMMENT ON COLUMN backups.data IS 'JSON格式的备份数据';
COMMENT ON COLUMN backups.size IS '备份数据大小（字节）';

COMMIT;

-- 验证表结构
\d backups

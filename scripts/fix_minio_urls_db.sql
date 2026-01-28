-- 修复服务器2上MinIO URL的SQL脚本
-- 将 127.0.0.1:9000 替换为 39.105.12.124:9000

-- 查看需要修复的版本
SELECT id, version_name, version_code, file_url
FROM app_versions
WHERE file_url LIKE '%127.0.0.1:9000%'
ORDER BY created_at DESC;

-- 执行修复
UPDATE app_versions
SET file_url = REPLACE(file_url, 'http://127.0.0.1:9000', 'http://39.105.12.124:9000'),
    updated_at = NOW()
WHERE file_url LIKE '%127.0.0.1:9000%';

-- 验证修复结果
SELECT id, version_name, version_code, file_url
FROM app_versions
WHERE version_code IN (57, 58, 59)
ORDER BY version_code DESC;

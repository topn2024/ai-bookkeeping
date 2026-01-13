-- 修复服务器2的MinIO URL问题
-- 将所有版本记录中的 localhost:9000 替换为 39.105.12.124:9000

-- 1. 查看需要修复的记录
SELECT
    id,
    version_name,
    version_code,
    file_url,
    patch_file_url
FROM app_versions
WHERE file_url LIKE '%localhost:9000%'
   OR patch_file_url LIKE '%localhost:9000%';

-- 2. 更新 file_url
UPDATE app_versions
SET
    file_url = REPLACE(file_url, 'localhost:9000', '39.105.12.124:9000'),
    updated_at = NOW()
WHERE file_url LIKE '%localhost:9000%';

-- 3. 更新 patch_file_url (如果有增量包)
UPDATE app_versions
SET
    patch_file_url = REPLACE(patch_file_url, 'localhost:9000', '39.105.12.124:9000'),
    updated_at = NOW()
WHERE patch_file_url LIKE '%localhost:9000%';

-- 4. 验证修复结果
SELECT
    id,
    version_name,
    version_code,
    file_url,
    patch_file_url
FROM app_versions
WHERE file_url LIKE '%39.105.12.124:9000%'
ORDER BY version_code DESC
LIMIT 10;

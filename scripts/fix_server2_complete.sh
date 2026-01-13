#!/bin/bash
#
# 服务器2完整修复脚本
# 修复MinIO配置并更新所有现有版本记录的URL
#
# 执行方式（在服务器2上运行）:
#   chmod +x fix_server2_complete.sh
#   ./fix_server2_complete.sh
#

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "=========================================="
echo "服务器2 MinIO配置修复"
echo "=========================================="
echo ""

# 检查是否在服务器2上
HOSTNAME=$(hostname)
print_info "当前主机: $HOSTNAME"

# 配置路径
ENV_FILE="/home/ai-bookkeeping/app/server/.env"
DB_NAME="ai_bookkeeping"
DB_USER="ai_bookkeeping"

# 1. 备份.env文件
print_info "[1/5] 备份配置文件..."
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    print_success "配置文件已备份"
else
    print_error "配置文件不存在: $ENV_FILE"
    exit 1
fi

# 2. 更新MINIO_ENDPOINT
print_info "[2/5] 更新MINIO_ENDPOINT配置..."

# 检查当前配置
CURRENT_ENDPOINT=$(grep "^MINIO_ENDPOINT=" "$ENV_FILE" | cut -d= -f2)
print_info "当前配置: MINIO_ENDPOINT=$CURRENT_ENDPOINT"

if [ "$CURRENT_ENDPOINT" = "localhost:9000" ]; then
    # 使用sed替换
    sudo sed -i 's|^MINIO_ENDPOINT=localhost:9000|MINIO_ENDPOINT=39.105.12.124:9000|g' "$ENV_FILE"
    NEW_ENDPOINT=$(grep "^MINIO_ENDPOINT=" "$ENV_FILE" | cut -d= -f2)
    print_success "已更新为: MINIO_ENDPOINT=$NEW_ENDPOINT"
else
    print_warning "MINIO_ENDPOINT不是localhost:9000，跳过更新"
fi

# 3. 重启服务
print_info "[3/5] 重启后端服务..."
sudo systemctl restart ai-bookkeeping
sleep 3

# 检查服务状态
if sudo systemctl is-active --quiet ai-bookkeeping; then
    print_success "服务已重启"
else
    print_error "服务启动失败"
    sudo systemctl status ai-bookkeeping
    exit 1
fi

# 4. 更新数据库中的现有记录
print_info "[4/5] 更新数据库中的URL记录..."

# 执行SQL更新
sudo -u postgres psql -d "$DB_NAME" <<'EOSQL'
-- 更新 file_url
UPDATE app_versions
SET
    file_url = REPLACE(file_url, 'localhost:9000', '39.105.12.124:9000'),
    updated_at = NOW()
WHERE file_url LIKE '%localhost:9000%';

-- 更新 patch_file_url
UPDATE app_versions
SET
    patch_file_url = REPLACE(patch_file_url, 'localhost:9000', '39.105.12.124:9000'),
    updated_at = NOW()
WHERE patch_file_url LIKE '%localhost:9000%';

-- 显示更新结果
SELECT
    'Updated' as status,
    COUNT(*) as count
FROM app_versions
WHERE file_url LIKE '%39.105.12.124:9000%';
EOSQL

print_success "数据库更新完成"

# 5. 验证修复
print_info "[5/5] 验证修复结果..."

# 测试API
TOKEN=$(curl -k -s -X POST "https://localhost/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' | \
    python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

if [ -n "$TOKEN" ]; then
    LATEST_URL=$(curl -k -s "https://localhost/admin/app-versions/latest" \
        -H "Authorization: Bearer $TOKEN" | \
        python3 -c 'import sys, json; print(json.load(sys.stdin).get("file_url", ""))' 2>/dev/null)

    echo ""
    echo "最新版本的file_url: $LATEST_URL"
    echo ""

    if echo "$LATEST_URL" | grep -q "39.105.12.124:9000"; then
        print_success "✓ 修复成功！URL已更新为公网地址"
    elif echo "$LATEST_URL" | grep -q "localhost:9000"; then
        print_error "✗ 修复失败，URL仍为localhost"
        exit 1
    else
        print_warning "⚠ 无法确认修复状态"
    fi
else
    print_warning "无法验证API，请手动检查"
fi

echo ""
echo "=========================================="
echo "修复完成"
echo "=========================================="
echo ""
echo "接下来的操作:"
echo "1. 测试从外部访问MinIO: curl -I http://39.105.12.124:9000/ai-bookkeeping/"
echo "2. 在客户端检查是否能正常下载APK"
echo "3. 运行版本同步脚本测试: ./scripts/sync_version.sh --auto --dry-run"
echo ""

exit 0

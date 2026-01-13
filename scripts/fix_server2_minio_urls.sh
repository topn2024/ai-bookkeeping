#!/bin/bash
#
# 修复服务器2的MinIO URL问题
# 将 localhost:9000 替换为 39.105.12.124:9000
#
# 用法:
#   ./scripts/fix_server2_minio_urls.sh
#
# 环境变量:
#   ADMIN_PASSWORD      管理员密码 (默认: admin123)
#

set -e

# 配置
SERVER2_URL="${SERVER2_URL:-https://39.105.12.124}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
echo "修复服务器2的MinIO URL"
echo "=========================================="
echo ""
echo "服务器: $SERVER2_URL"
echo "操作: localhost:9000 -> 39.105.12.124:9000"
echo ""

# 1. 登录
print_info "[1/3] 登录服务器2..."
TOKEN=$(curl -k -s -X POST "${SERVER2_URL}/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" | \
    python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

if [ -z "$TOKEN" ]; then
    print_error "登录失败"
    exit 1
fi
print_success "登录成功"

# 2. 获取所有版本记录
print_info "[2/3] 获取所有版本记录..."
VERSIONS=$(curl -k -s "${SERVER2_URL}/admin/app-versions?limit=1000" \
    -H "Authorization: Bearer $TOKEN")

# 提取所有需要修复的版本ID和当前URL
NEED_FIX=$(echo "$VERSIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
count = 0
for item in data.get('items', []):
    if item.get('file_url', '').startswith('http://localhost:9000'):
        count += 1
        print(f\"{item['id']}|{item['version_name']}+{item['version_code']}|{item['file_url']}\")
print(f'TOTAL:{count}', file=sys.stderr)
")

TOTAL_COUNT=$(echo "$NEED_FIX" | wc -l | tr -d ' ')
if [ "$TOTAL_COUNT" -eq 0 ] || [ -z "$NEED_FIX" ]; then
    print_success "没有需要修复的版本"
    exit 0
fi

print_info "找到 $TOTAL_COUNT 个需要修复的版本"
echo ""

# 3. 修复每个版本
print_info "[3/3] 批量修复URL..."
FIXED=0
FAILED=0

while IFS='|' read -r VERSION_ID VERSION_NAME OLD_URL; do
    [ -z "$VERSION_ID" ] && continue

    # 构造新URL
    NEW_URL=$(echo "$OLD_URL" | sed 's|http://localhost:9000|http://39.105.12.124:9000|g')

    echo "  修复: $VERSION_NAME"
    echo "    旧: $OLD_URL"
    echo "    新: $NEW_URL"

    # 更新版本记录
    RESPONSE=$(curl -k -s -X PATCH "${SERVER2_URL}/admin/app-versions/${VERSION_ID}" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"file_url\":\"${NEW_URL}\"}")

    # 检查是否成功
    if echo "$RESPONSE" | grep -q '"id"'; then
        print_success "  ✓ 修复成功"
        FIXED=$((FIXED + 1))
    else
        print_error "  ✗ 修复失败: $RESPONSE"
        FAILED=$((FAILED + 1))
    fi
    echo ""
done <<< "$NEED_FIX"

echo ""
echo "=========================================="
echo "修复完成"
echo "=========================================="
echo ""
echo "总数: $TOTAL_COUNT"
echo "成功: $FIXED"
echo "失败: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0

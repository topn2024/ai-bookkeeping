#!/bin/bash
#
# 远程修复服务器2的MinIO配置
# 从本地机器执行，通过SSH连接到服务器2
#
# 前置条件:
#   - 需要服务器2的SSH访问权限
#   - 需要sudo权限
#
# 用法:
#   ./scripts/remote_fix_server2.sh
#

set -e

# 配置
SERVER2_IP="39.105.12.124"
SERVER2_USER="${SERVER2_USER:-root}"

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
echo "远程修复服务器2 MinIO配置"
echo "=========================================="
echo ""
echo "目标服务器: ${SERVER2_USER}@${SERVER2_IP}"
echo ""

# 测试SSH连接
print_info "测试SSH连接..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${SERVER2_USER}@${SERVER2_IP}" "echo 'SSH连接成功'" 2>/dev/null; then
    print_success "SSH连接正常"
else
    print_error "SSH连接失败"
    echo ""
    echo "请确保:"
    echo "1. 已配置SSH密钥: ssh-copy-id ${SERVER2_USER}@${SERVER2_IP}"
    echo "2. 或设置环境变量: export SERVER2_USER=<用户名>"
    echo ""
    echo "手动修复方案:"
    echo "1. 登录服务器: ssh ${SERVER2_USER}@${SERVER2_IP}"
    echo "2. 上传修复脚本: scp scripts/fix_server2_complete.sh ${SERVER2_USER}@${SERVER2_IP}:/tmp/"
    echo "3. 执行修复: sudo bash /tmp/fix_server2_complete.sh"
    echo ""
    exit 1
fi

# 上传修复脚本
print_info "上传修复脚本到服务器..."
scp scripts/fix_server2_complete.sh "${SERVER2_USER}@${SERVER2_IP}:/tmp/fix_server2.sh"
print_success "脚本已上传"

# 远程执行修复
print_info "在服务器上执行修复..."
echo ""
ssh "${SERVER2_USER}@${SERVER2_IP}" "sudo bash /tmp/fix_server2.sh"

# 清理
print_info "清理临时文件..."
ssh "${SERVER2_USER}@${SERVER2_IP}" "rm -f /tmp/fix_server2.sh"

echo ""
echo "=========================================="
echo "远程修复完成"
echo "=========================================="
echo ""

# 验证修复
print_info "验证修复结果..."
sleep 2

TOKEN=$(curl -k -s -X POST "https://${SERVER2_IP}/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123"}' | \
    python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

if [ -n "$TOKEN" ]; then
    LATEST_VERSION=$(curl -k -s "https://${SERVER2_IP}/admin/app-versions/latest" \
        -H "Authorization: Bearer $TOKEN" | \
        python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"{d['version_name']}+{d['version_code']}: {d['file_url'][:80]}\")" 2>/dev/null)

    echo ""
    echo "最新版本:"
    echo "  $LATEST_VERSION"
    echo ""

    if echo "$LATEST_VERSION" | grep -q "39.105.12.124:9000"; then
        print_success "✓ 验证通过！URL已修复"
    else
        print_warning "⚠ 验证未通过，请手动检查"
    fi
fi

echo ""
echo "后续步骤:"
echo "1. 测试版本同步: ./scripts/sync_version.sh --auto"
echo "2. 检查版本一致性: ./scripts/check_version_consistency.sh"
echo ""

exit 0

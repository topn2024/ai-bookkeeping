#!/bin/bash
#
# 版本同步脚本 - 从服务器2同步到服务器1
# 用于确保两台服务器的版本保持一致
#
# 用法:
#   ./scripts/sync_version.sh [选项]
#
# 选项:
#   --version VERSION   指定要同步的版本号 (例如 2.0.6)
#   --code CODE         指定要同步的构建号 (例如 48)
#   --auto              自动同步服务器2的最新版本到服务器1
#   --dry-run           仅显示将要执行的操作，不实际同步
#
# 环境变量:
#   ADMIN_PASSWORD      管理员密码 (默认: admin123)
#   SERVER1_URL         服务器1地址 (默认: https://160.202.238.29)
#   SERVER2_URL         服务器2地址 (默认: https://39.105.12.124)
#

set -e

# 默认值
SERVER1_URL="${SERVER1_URL:-https://160.202.238.29}"
SERVER2_URL="${SERVER2_URL:-https://39.105.12.124}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
DRY_RUN=false
AUTO_MODE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
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

# 帮助信息
show_help() {
    echo "版本同步脚本 - 从服务器2同步到服务器1"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --version VERSION   指定要同步的版本号 (例如 2.0.6)"
    echo "  --code CODE         指定要同步的构建号 (例如 48)"
    echo "  --auto              自动同步服务器2的最新版本到服务器1"
    echo "  --dry-run           仅显示将要执行的操作，不实际同步"
    echo "  -h, --help          显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  ADMIN_PASSWORD      管理员密码 (默认: admin123)"
    echo "  SERVER1_URL         服务器1地址 (默认: https://160.202.238.29)"
    echo "  SERVER2_URL         服务器2地址 (默认: https://39.105.12.124)"
    echo ""
    echo "示例:"
    echo "  # 自动同步最新版本"
    echo "  ./scripts/sync_version.sh --auto"
    echo ""
    echo "  # 同步指定版本"
    echo "  ./scripts/sync_version.sh --version 2.0.6 --code 48"
    echo ""
    echo "  # 预览同步操作（不实际执行）"
    echo "  ./scripts/sync_version.sh --auto --dry-run"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION_NAME="$2"
            shift 2
            ;;
        --code)
            VERSION_CODE="$2"
            shift 2
            ;;
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证参数
if [ "$AUTO_MODE" = false ] && ([ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ]); then
    print_error "请指定 --auto 或同时指定 --version 和 --code"
    show_help
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    print_error "请设置 ADMIN_PASSWORD 环境变量"
    exit 1
fi

echo ""
echo "=========================================="
echo "版本同步工具"
echo "=========================================="
echo ""
echo "服务器2 (源): $SERVER2_URL"
echo "服务器1 (目标): $SERVER1_URL"
echo "模式: $([ "$AUTO_MODE" = true ] && echo "自动同步最新版本" || echo "同步指定版本 $VERSION_NAME+$VERSION_CODE")"
echo "预览模式: $([ "$DRY_RUN" = true ] && echo "是（不会实际执行）" || echo "否")"
echo ""

# 登录服务器2
print_info "[1/6] 登录服务器2..."
TOKEN2=$(curl -k -s -X POST "${SERVER2_URL}/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" | \
    python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

if [ -z "$TOKEN2" ]; then
    print_error "服务器2登录失败"
    exit 1
fi
print_success "服务器2登录成功"

# 获取服务器2的版本信息
if [ "$AUTO_MODE" = true ]; then
    print_info "[2/6] 获取服务器2的最新版本..."
    VERSION_INFO=$(curl -k -s "${SERVER2_URL}/admin/app-versions/latest" \
        -H "Authorization: Bearer $TOKEN2")

    VERSION_NAME=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["version_name"])' 2>/dev/null)
    VERSION_CODE=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["version_code"])' 2>/dev/null)
    VERSION_ID=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["id"])' 2>/dev/null)
    RELEASE_NOTES=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["release_notes"])' 2>/dev/null)
    IS_FORCE_UPDATE=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(str(json.load(sys.stdin).get("is_force_update", False)).lower())' 2>/dev/null)

    print_success "找到最新版本: $VERSION_NAME+$VERSION_CODE"
else
    print_info "[2/6] 查找服务器2上的指定版本..."
    # 获取所有版本并查找匹配的版本
    VERSIONS=$(curl -k -s "${SERVER2_URL}/admin/app-versions?limit=100" \
        -H "Authorization: Bearer $TOKEN2")

    VERSION_INFO=$(echo "$VERSIONS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('items', []):
    if item['version_name'] == '${VERSION_NAME}' and item['version_code'] == ${VERSION_CODE}:
        print(json.dumps(item))
        break
" 2>/dev/null)

    if [ -z "$VERSION_INFO" ]; then
        print_error "在服务器2上未找到版本 $VERSION_NAME+$VERSION_CODE"
        exit 1
    fi

    VERSION_ID=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["id"])' 2>/dev/null)
    RELEASE_NOTES=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["release_notes"])' 2>/dev/null)
    IS_FORCE_UPDATE=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(str(json.load(sys.stdin).get("is_force_update", False)).lower())' 2>/dev/null)

    print_success "找到版本: $VERSION_NAME+$VERSION_CODE (ID: $VERSION_ID)"
fi

# 下载APK
print_info "[3/6] 从服务器2下载APK..."
APK_URL=$(echo "$VERSION_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["file_url"])' 2>/dev/null)
TEMP_APK="/tmp/sync_apk_${VERSION_NAME}_${VERSION_CODE}.apk"

if [ "$DRY_RUN" = false ]; then
    curl -k -s -o "$TEMP_APK" "$APK_URL"

    if [ ! -f "$TEMP_APK" ]; then
        print_error "APK下载失败"
        exit 1
    fi

    APK_SIZE=$(du -h "$TEMP_APK" | cut -f1)
    print_success "APK下载完成 ($APK_SIZE)"
else
    print_warning "预览模式：跳过APK下载"
fi

# 登录服务器1
print_info "[4/6] 登录服务器1..."
TOKEN1=$(curl -k -s -X POST "${SERVER1_URL}/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" | \
    python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

if [ -z "$TOKEN1" ]; then
    print_error "服务器1登录失败"
    [ "$DRY_RUN" = false ] && rm -f "$TEMP_APK"
    exit 1
fi
print_success "服务器1登录成功"

# 检查服务器1是否已存在该版本
print_info "[5/6] 检查服务器1上的版本..."
EXISTING_VERSION=$(curl -k -s "${SERVER1_URL}/admin/app-versions?version_name=${VERSION_NAME}&version_code=${VERSION_CODE}&limit=1" \
    -H "Authorization: Bearer $TOKEN1" | \
    python3 -c 'import sys, json; items=json.load(sys.stdin).get("items", []); print(items[0]["id"] if items else "")' 2>/dev/null)

if [ -n "$EXISTING_VERSION" ]; then
    print_warning "服务器1已存在版本 $VERSION_NAME+$VERSION_CODE (ID: $EXISTING_VERSION)"
    print_warning "将更新现有版本"
    SERVER1_VERSION_ID="$EXISTING_VERSION"
else
    print_info "服务器1不存在此版本，将创建新版本"

    if [ "$DRY_RUN" = false ]; then
        # 创建版本记录
        CREATE_DATA=$(node -e "
const data = {
    version_name: process.argv[1],
    version_code: parseInt(process.argv[2]),
    platform: 'android',
    release_notes: process.argv[3],
    is_force_update: process.argv[4] === 'true'
};
console.log(JSON.stringify(data));
" "$VERSION_NAME" "$VERSION_CODE" "$RELEASE_NOTES" "$IS_FORCE_UPDATE")

        CREATE_RESPONSE=$(curl -k -s -X POST "${SERVER1_URL}/admin/app-versions" \
            -H "Authorization: Bearer $TOKEN1" \
            -H "Content-Type: application/json; charset=utf-8" \
            -d "$CREATE_DATA")

        SERVER1_VERSION_ID=$(echo "$CREATE_RESPONSE" | python3 -c 'import sys, json; print(json.load(sys.stdin)["id"])' 2>/dev/null)

        if [ -z "$SERVER1_VERSION_ID" ]; then
            print_error "服务器1版本创建失败: $CREATE_RESPONSE"
            rm -f "$TEMP_APK"
            exit 1
        fi

        print_success "版本记录创建成功 (ID: $SERVER1_VERSION_ID)"
    else
        print_warning "预览模式：跳过版本创建"
    fi
fi

# 上传APK到服务器1
print_info "[6/6] 上传APK到服务器1..."
if [ "$DRY_RUN" = false ]; then
    UPLOAD_RESPONSE=$(curl -k -s -X POST "${SERVER1_URL}/admin/app-versions/${SERVER1_VERSION_ID}/upload-apk" \
        -H "Authorization: Bearer $TOKEN1" \
        -F "file=@$TEMP_APK")

    if echo "$UPLOAD_RESPONSE" | grep -q "APK上传成功"; then
        print_success "APK上传成功"

        # 发布版本
        PUBLISH_RESPONSE=$(curl -k -s -X POST "${SERVER1_URL}/admin/app-versions/${SERVER1_VERSION_ID}/publish" \
            -H "Authorization: Bearer $TOKEN1")

        if echo "$PUBLISH_RESPONSE" | grep -q "版本已发布"; then
            print_success "版本已发布到服务器1"
        else
            print_warning "版本发布可能失败: $PUBLISH_RESPONSE"
        fi
    else
        print_error "APK上传失败: $UPLOAD_RESPONSE"
        rm -f "$TEMP_APK"
        exit 1
    fi

    # 清理临时文件
    rm -f "$TEMP_APK"
else
    print_warning "预览模式：跳过APK上传和发布"
fi

echo ""
echo "=========================================="
echo "同步完成"
echo "=========================================="
echo ""
echo "版本: $VERSION_NAME+$VERSION_CODE"
echo "服务器2 (源): $SERVER2_URL ✓"
echo "服务器1 (目标): $SERVER1_URL ✓"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "这是预览模式，没有实际执行同步操作"
    echo "移除 --dry-run 参数以执行实际同步"
fi

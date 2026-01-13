#!/bin/bash
#
# 统一发布脚本 (新策略)
# 策略: 先发布到服务器2，然后自动同步到服务器1
#
# 用法:
#   ./scripts/publish_unified.sh --version VERSION --code CODE --notes "更新说明" [选项]
#
# 选项:
#   --version VERSION       版本号 (必需)
#   --code CODE            构建号 (必需)
#   --notes NOTES          更新说明 (必需)
#   --force                标记为强制更新
#   --skip-build           跳过APK构建，使用已存在的APK
#   --skip-sync            仅发布到服务器2，不同步到服务器1
#   --auto-confirm         自动确认，不询问
#
# 环境变量:
#   ADMIN_PASSWORD         管理员密码 (默认: admin123)
#   FLUTTER_CMD            Flutter命令路径 (默认: flutter)
#

set -e

# 默认值
SERVER1_URL="https://160.202.238.29"
SERVER2_URL="https://39.105.12.124"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"
FLUTTER_CMD="${FLUTTER_CMD:-flutter}"
SKIP_BUILD=false
SKIP_SYNC=false
AUTO_CONFIRM=false
IS_FORCE_UPDATE=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo "统一发布脚本 (新策略: 服务器2 → 服务器1)"
    echo ""
    echo "用法: $0 --version VERSION --code CODE --notes \"更新说明\" [选项]"
    echo ""
    echo "必需参数:"
    echo "  --version VERSION   版本号 (例如 2.0.6)"
    echo "  --code CODE         构建号 (例如 48)"
    echo "  --notes NOTES       更新说明"
    echo ""
    echo "可选参数:"
    echo "  --force             标记为强制更新"
    echo "  --skip-build        跳过APK构建"
    echo "  --skip-sync         仅发布到服务器2，不同步到服务器1"
    echo "  --auto-confirm      自动确认，不询问"
    echo "  -h, --help          显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  ADMIN_PASSWORD      管理员密码 (默认: admin123)"
    echo "  FLUTTER_CMD         Flutter命令路径 (默认: flutter)"
    echo ""
    echo "示例:"
    echo "  # 完整发布流程"
    echo "  ./scripts/publish_unified.sh \\"
    echo "    --version 2.0.7 \\"
    echo "    --code 49 \\"
    echo "    --notes \"修复若干问题\""
    echo ""
    echo "  # 跳过构建，使用已有APK"
    echo "  ./scripts/publish_unified.sh \\"
    echo "    --version 2.0.7 \\"
    echo "    --code 49 \\"
    echo "    --notes \"修复若干问题\" \\"
    echo "    --skip-build"
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --code)
            CODE="$2"
            shift 2
            ;;
        --notes)
            NOTES="$2"
            shift 2
            ;;
        --force)
            IS_FORCE_UPDATE=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --skip-sync)
            SKIP_SYNC=true
            shift
            ;;
        --auto-confirm)
            AUTO_CONFIRM=true
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

# 验证必需参数
if [ -z "$VERSION" ] || [ -z "$CODE" ] || [ -z "$NOTES" ]; then
    print_error "缺少必需参数"
    show_help
    exit 1
fi

# 检查所有服务器的现有版本
check_server_versions() {
    echo ""
    echo "=========================================="
    echo "检查服务器现有版本"
    echo "=========================================="
    echo ""

    # 检查服务器1
    print_info "检查服务器1 (${SERVER1_URL})..."
    SERVER1_VERSION=""
    SERVER1_CODE=0
    TOKEN1=$(curl -k -s -X POST "${SERVER1_URL}/admin/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null | \
        python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

    if [ -n "$TOKEN1" ]; then
        SERVER1_INFO=$(curl -k -s "${SERVER1_URL}/admin/app-versions/latest" \
            -H "Authorization: Bearer $TOKEN1" 2>/dev/null)
        SERVER1_VERSION=$(echo "$SERVER1_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["version_name"])' 2>/dev/null)
        SERVER1_CODE=$(echo "$SERVER1_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["version_code"])' 2>/dev/null)
        echo "  当前版本: ${SERVER1_VERSION}+${SERVER1_CODE}"
    else
        print_warning "  无法连接到服务器1"
    fi

    # 检查服务器2
    print_info "检查服务器2 (${SERVER2_URL})..."
    SERVER2_VERSION=""
    SERVER2_CODE=0
    TOKEN2=$(curl -k -s -X POST "${SERVER2_URL}/admin/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"admin\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null | \
        python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

    if [ -n "$TOKEN2" ]; then
        SERVER2_INFO=$(curl -k -s "${SERVER2_URL}/admin/app-versions/latest" \
            -H "Authorization: Bearer $TOKEN2" 2>/dev/null)
        SERVER2_VERSION=$(echo "$SERVER2_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["version_name"])' 2>/dev/null)
        SERVER2_CODE=$(echo "$SERVER2_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["version_code"])' 2>/dev/null)
        echo "  当前版本: ${SERVER2_VERSION}+${SERVER2_CODE}"
    else
        print_warning "  无法连接到服务器2"
    fi

    # 找出最高版本号
    HIGHEST_CODE=0
    HIGHEST_VERSION=""
    HIGHEST_SERVER=""

    if [ "$SERVER1_CODE" -gt "$HIGHEST_CODE" ]; then
        HIGHEST_CODE=$SERVER1_CODE
        HIGHEST_VERSION=$SERVER1_VERSION
        HIGHEST_SERVER="服务器1"
    fi

    if [ "$SERVER2_CODE" -gt "$HIGHEST_CODE" ]; then
        HIGHEST_CODE=$SERVER2_CODE
        HIGHEST_VERSION=$SERVER2_VERSION
        HIGHEST_SERVER="服务器2"
    fi

    echo ""
    if [ "$HIGHEST_CODE" -gt 0 ]; then
        print_info "当前最高版本: ${HIGHEST_VERSION}+${HIGHEST_CODE} (来自${HIGHEST_SERVER})"

        # 版本号验证
        if [ "$CODE" -le "$HIGHEST_CODE" ]; then
            echo ""
            print_error "❌ 版本号冲突！"
            print_error "   要发布的版本: ${VERSION}+${CODE}"
            print_error "   服务器最高版本: ${HIGHEST_VERSION}+${HIGHEST_CODE}"
            print_error ""
            print_error "构建号 (CODE) 必须大于 ${HIGHEST_CODE}"

            # 建议新版本号
            SUGGESTED_CODE=$((HIGHEST_CODE + 1))
            print_warning "建议使用: --code ${SUGGESTED_CODE}"
            echo ""
            exit 1
        elif [ "$CODE" -eq $((HIGHEST_CODE + 1)) ]; then
            print_success "✓ 版本号验证通过 (正常递增)"
        else
            print_warning "⚠️  版本号跳跃: ${HIGHEST_CODE} -> ${CODE} (跳过了 $((CODE - HIGHEST_CODE - 1)) 个版本号)"
        fi
    else
        print_warning "未找到服务器现有版本，这可能是首次发布"
    fi

    echo ""
}

# 执行版本检查
check_server_versions

# 确定APK路径
APK_PATH="app/build/app/outputs/flutter-apk/app-release.apk"

echo ""
echo "=========================================="
echo "统一发布 AI智能记账 v${VERSION}+${CODE}"
echo "=========================================="
echo ""
echo "版本: ${VERSION}"
echo "构建号: ${CODE}"
echo "强制更新: $([ "$IS_FORCE_UPDATE" = true ] && echo "是" || echo "否")"
echo ""
echo "发布策略:"
echo "  1️⃣  发布到服务器2 (主服务器): ${SERVER2_URL}"
if [ "$SKIP_SYNC" = false ]; then
    echo "  2️⃣  自动同步到服务器1 (备份服务器): ${SERVER1_URL}"
else
    echo "  ⏭️  跳过同步到服务器1"
fi
echo ""

# 询问确认
if [ "$AUTO_CONFIRM" = false ]; then
    read -p "确认发布？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "发布已取消"
        exit 1
    fi
fi

# 1. 构建APK
if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo "=========================================="
    echo "[1/3] 构建 Release APK"
    echo "=========================================="

    cd app
    $FLUTTER_CMD clean
    $FLUTTER_CMD pub get
    $FLUTTER_CMD build apk --release --no-tree-shake-icons
    cd ..

    if [ ! -f "$APK_PATH" ]; then
        print_error "APK构建失败"
        exit 1
    fi

    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    print_success "APK构建成功: $APK_SIZE"
else
    echo ""
    echo "=========================================="
    echo "[1/3] 跳过APK构建"
    echo "=========================================="

    if [ ! -f "$APK_PATH" ]; then
        print_error "APK文件不存在: $APK_PATH"
        print_error "请先构建APK或移除 --skip-build 参数"
        exit 1
    fi

    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    print_info "使用已存在的APK: $APK_SIZE"
fi

# 2. 发布到服务器2 (主服务器)
echo ""
echo "=========================================="
echo "[2/3] 发布到服务器2 (主服务器)"
echo "=========================================="
echo ""

API_BASE_URL="$SERVER2_URL" \
ADMIN_PASSWORD="$ADMIN_PASSWORD" \
FLUTTER_CMD="$FLUTTER_CMD" \
./scripts/publish_apk.sh \
  --version "$VERSION" \
  --code "$CODE" \
  --notes "$NOTES" \
  --apk "$APK_PATH" \
  $([ "$IS_FORCE_UPDATE" = true ] && echo "--force") \
  --publish

if [ $? -eq 0 ]; then
    print_success "服务器2发布成功"
    SERVER2_SUCCESS=true
else
    print_error "服务器2发布失败"
    SERVER2_SUCCESS=false
    exit 1
fi

# 3. 同步到服务器1 (备份服务器)
if [ "$SKIP_SYNC" = false ]; then
    echo ""
    echo "=========================================="
    echo "[3/3] 同步到服务器1 (备份服务器)"
    echo "=========================================="
    echo ""

    # 等待几秒让服务器2完成处理
    sleep 2

    SERVER1_URL="$SERVER1_URL" \
    SERVER2_URL="$SERVER2_URL" \
    ADMIN_PASSWORD="$ADMIN_PASSWORD" \
    ./scripts/sync_version.sh --auto

    if [ $? -eq 0 ]; then
        print_success "同步到服务器1成功"
        SERVER1_SUCCESS=true
    else
        print_error "同步到服务器1失败"
        SERVER1_SUCCESS=false

        print_warning "服务器2已成功发布，但同步到服务器1失败"
        print_warning "可以稍后手动运行: ./scripts/sync_version.sh --auto"
    fi
else
    echo ""
    echo "=========================================="
    echo "[3/3] 跳过同步到服务器1"
    echo "=========================================="
    SERVER1_SUCCESS="skipped"
fi

# 4. 验证版本一致性
echo ""
echo "=========================================="
echo "📊 发布结果汇总"
echo "=========================================="
echo ""

if [ "$SKIP_SYNC" = false ]; then
    # 运行一致性检查
    ./scripts/check_version_consistency.sh --json > /tmp/version_check.json 2>/dev/null || true

    if [ -f /tmp/version_check.json ]; then
        CONSISTENT=$(cat /tmp/version_check.json | python3 -c 'import sys, json; print(json.load(sys.stdin).get("consistent", False))' 2>/dev/null)

        echo "服务器2 (主服务器): $SERVER2_URL"
        echo "  状态: ✓ 已发布"
        echo "  版本: ${VERSION}+${CODE}"
        echo ""

        echo "服务器1 (备份服务器): $SERVER1_URL"
        if [ "$SERVER1_SUCCESS" = true ]; then
            echo "  状态: ✓ 已同步"
        else
            echo "  状态: ✗ 同步失败"
        fi
        echo ""

        if [ "$CONSISTENT" = "True" ]; then
            print_success "✓ 版本一致性检查通过"
            echo ""
            echo "=========================================="
            echo "🎉 统一发布完成！"
            echo "=========================================="
            echo ""
            echo "版本 ${VERSION}+${CODE} 已成功发布"
            echo "用户可以通过应用内更新功能获取新版本"
        else
            print_warning "⚠️  版本不一致"
            echo ""
            echo "请运行以下命令手动同步:"
            echo "  ./scripts/sync_version.sh --auto"
        fi

        rm -f /tmp/version_check.json
    fi
else
    echo "服务器2 (主服务器): $SERVER2_URL"
    echo "  状态: ✓ 已发布"
    echo "  版本: ${VERSION}+${CODE}"
    echo ""
    echo "服务器1: 未同步 (使用 --skip-sync 参数)"
    echo ""
    echo "如需同步到服务器1，请运行:"
    echo "  ./scripts/sync_version.sh --auto"
fi

echo ""
exit 0

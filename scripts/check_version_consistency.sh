#!/bin/bash
#
# 版本一致性检查脚本
# 检查两台服务器的版本是否一致
#
# 用法:
#   ./scripts/check_version_consistency.sh [选项]
#
# 选项:
#   --auto-sync         如果发现不一致，自动从服务器2同步到服务器1
#   --notify            发送通知（当前仅输出，可扩展为邮件/企业微信等）
#   --json              以JSON格式输出结果
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
AUTO_SYNC=false
JSON_OUTPUT=false
NOTIFY=false

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-sync)
            AUTO_SYNC=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --notify)
            NOTIFY=true
            shift
            ;;
        -h|--help)
            echo "版本一致性检查脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --auto-sync     如果发现不一致，自动同步"
            echo "  --json          以JSON格式输出结果"
            echo "  --notify        发送通知"
            echo "  -h, --help      显示帮助信息"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

# 获取服务器版本信息
get_server_version() {
    local server_url=$1
    local server_name=$2

    # 登录
    local token=$(curl -k -s -X POST "${server_url}/admin/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}" 2>/dev/null | \
        python3 -c 'import sys, json; print(json.load(sys.stdin)["access_token"])' 2>/dev/null)

    if [ -z "$token" ]; then
        echo "ERROR: ${server_name}登录失败" >&2
        return 1
    fi

    # 获取最新版本
    local version_info=$(curl -k -s "${server_url}/admin/app-versions/latest" \
        -H "Authorization: Bearer $token" 2>/dev/null)

    if [ -z "$version_info" ]; then
        echo "ERROR: 无法获取${server_name}版本信息" >&2
        return 1
    fi

    echo "$version_info"
}

# 比较版本号
compare_versions() {
    local v1=$1
    local v2=$2

    if [ "$v1" = "$v2" ]; then
        return 0  # 相等
    else
        return 1  # 不相等
    fi
}

# 主逻辑
if [ "$JSON_OUTPUT" = false ]; then
    echo ""
    echo "=========================================="
    echo "版本一致性检查"
    echo "=========================================="
    echo ""
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
fi

# 获取服务器1版本
if [ "$JSON_OUTPUT" = false ]; then
    echo "正在检查服务器1..."
fi
SERVER1_INFO=$(get_server_version "$SERVER1_URL" "服务器1")
if [ $? -ne 0 ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo '{"status":"error","message":"服务器1连接失败"}'
    else
        echo -e "${RED}✗ 服务器1连接失败${NC}"
    fi
    exit 1
fi

SERVER1_VERSION=$(echo "$SERVER1_INFO" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(f"{d[\"version_name\"]}+{d[\"version_code\"]}")' 2>/dev/null)
SERVER1_STATUS=$(echo "$SERVER1_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["status_text"])' 2>/dev/null)
SERVER1_PUBLISHED=$(echo "$SERVER1_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("published_at", "未发布"))' 2>/dev/null)

# 获取服务器2版本
if [ "$JSON_OUTPUT" = false ]; then
    echo "正在检查服务器2..."
fi
SERVER2_INFO=$(get_server_version "$SERVER2_URL" "服务器2")
if [ $? -ne 0 ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo '{"status":"error","message":"服务器2连接失败"}'
    else
        echo -e "${RED}✗ 服务器2连接失败${NC}"
    fi
    exit 1
fi

SERVER2_VERSION=$(echo "$SERVER2_INFO" | python3 -c 'import sys, json; d=json.load(sys.stdin); print(f"{d[\"version_name\"]}+{d[\"version_code\"]}")' 2>/dev/null)
SERVER2_STATUS=$(echo "$SERVER2_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin)["status_text"])' 2>/dev/null)
SERVER2_PUBLISHED=$(echo "$SERVER2_INFO" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("published_at", "未发布"))' 2>/dev/null)

# 比较版本
if compare_versions "$SERVER1_VERSION" "$SERVER2_VERSION"; then
    CONSISTENT=true
    RESULT="一致"
    COLOR=$GREEN
else
    CONSISTENT=false
    RESULT="不一致"
    COLOR=$RED
fi

# 输出结果
if [ "$JSON_OUTPUT" = true ]; then
    cat <<EOF
{
    "status": "success",
    "consistent": $CONSISTENT,
    "check_time": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "servers": {
        "server1": {
            "url": "$SERVER1_URL",
            "version": "$SERVER1_VERSION",
            "status": "$SERVER1_STATUS",
            "published_at": "$SERVER1_PUBLISHED"
        },
        "server2": {
            "url": "$SERVER2_URL",
            "version": "$SERVER2_VERSION",
            "status": "$SERVER2_STATUS",
            "published_at": "$SERVER2_PUBLISHED"
        }
    }
}
EOF
else
    echo ""
    echo "=========================================="
    echo "检查结果"
    echo "=========================================="
    echo ""
    echo "服务器1 ($SERVER1_URL):"
    echo "  版本: $SERVER1_VERSION"
    echo "  状态: $SERVER1_STATUS"
    echo "  发布时间: $SERVER1_PUBLISHED"
    echo ""
    echo "服务器2 ($SERVER2_URL):"
    echo "  版本: $SERVER2_VERSION"
    echo "  状态: $SERVER2_STATUS"
    echo "  发布时间: $SERVER2_PUBLISHED"
    echo ""
    echo -e "一致性: ${COLOR}${RESULT}${NC}"
    echo ""
fi

# 如果不一致且启用了自动同步
if [ "$CONSISTENT" = false ] && [ "$AUTO_SYNC" = true ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo "=========================================="
        echo "自动同步"
        echo "=========================================="
        echo ""
        echo "检测到版本不一致，开始自动同步..."
        echo ""
    fi

    # 调用同步脚本
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    "$SCRIPT_DIR/sync_version.sh" --auto

    if [ $? -eq 0 ]; then
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${GREEN}✓ 自动同步完成${NC}"
        fi
    else
        if [ "$JSON_OUTPUT" = false ]; then
            echo -e "${RED}✗ 自动同步失败${NC}"
        fi
        exit 1
    fi
fi

# 发送通知
if [ "$NOTIFY" = true ] && [ "$CONSISTENT" = false ]; then
    # 这里可以扩展为发送邮件、企业微信、钉钉等通知
    echo ""
    echo "=========================================="
    echo "通知"
    echo "=========================================="
    echo ""
    echo "⚠️  版本不一致警告"
    echo ""
    echo "服务器1: $SERVER1_VERSION"
    echo "服务器2: $SERVER2_VERSION"
    echo ""
    echo "请及时处理版本不一致问题"
    echo ""
fi

# 返回状态码
if [ "$CONSISTENT" = true ]; then
    exit 0
else
    exit 1
fi

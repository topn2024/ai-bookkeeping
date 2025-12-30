#!/bin/bash
#
# APK 发布脚本
# 用于一键发布新版本 APK 到服务器
#
# 用法:
#   ./scripts/publish_apk.sh \
#     --version 1.2.2 \
#     --code 19 \
#     --apk ./app/build/app/outputs/flutter-apk/app-release.apk \
#     --notes "更新说明" \
#     [--force]  # 可选：标记为强制更新
#
# 环境变量:
#   ADMIN_USERNAME: 管理员用户名 (默认: admin)
#   ADMIN_PASSWORD: 管理员密码 (必需)
#   API_BASE_URL: API 地址 (默认: https://160.202.238.29)
#

set -e

# 默认值
API_BASE_URL="${API_BASE_URL:-https://160.202.238.29}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
PLATFORM="android"
IS_FORCE_UPDATE="false"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    echo "APK 发布脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --version VERSION   版本号 (如 1.2.2)"
    echo "  --code CODE         构建号 (如 19)"
    echo "  --apk PATH          APK 文件路径"
    echo "  --notes NOTES       更新说明"
    echo "  --notes-en NOTES    英文更新说明 (可选)"
    echo "  --min-version VER   最低支持版本 (可选)"
    echo "  --force             标记为强制更新"
    echo "  --publish           创建后自动发布"
    echo "  -h, --help          显示帮助"
    echo ""
    echo "环境变量:"
    echo "  ADMIN_USERNAME      管理员用户名 (默认: admin)"
    echo "  ADMIN_PASSWORD      管理员密码 (必需)"
    echo "  API_BASE_URL        API 地址 (默认: https://160.202.238.29)"
    echo ""
    echo "示例:"
    echo "  ADMIN_PASSWORD=xxx ./scripts/publish_apk.sh \\"
    echo "    --version 1.2.2 \\"
    echo "    --code 19 \\"
    echo "    --apk ./app/build/app/outputs/flutter-apk/app-release.apk \\"
    echo "    --notes '- 修复若干问题' \\"
    echo "    --publish"
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
        --apk)
            APK_PATH="$2"
            shift 2
            ;;
        --notes)
            RELEASE_NOTES="$2"
            shift 2
            ;;
        --notes-en)
            RELEASE_NOTES_EN="$2"
            shift 2
            ;;
        --min-version)
            MIN_SUPPORTED_VERSION="$2"
            shift 2
            ;;
        --force)
            IS_FORCE_UPDATE="true"
            shift
            ;;
        --publish)
            AUTO_PUBLISH="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 验证必需参数
if [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ] || [ -z "$APK_PATH" ] || [ -z "$RELEASE_NOTES" ]; then
    echo -e "${RED}错误: 缺少必需参数${NC}"
    show_help
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}错误: 请设置 ADMIN_PASSWORD 环境变量${NC}"
    exit 1
fi

if [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}错误: APK 文件不存在: $APK_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}APK 发布脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "版本号: $VERSION_NAME"
echo "构建号: $VERSION_CODE"
echo "APK 路径: $APK_PATH"
echo "强制更新: $IS_FORCE_UPDATE"
echo "API 地址: $API_BASE_URL"
echo ""

# 1. 登录获取 Token
echo -e "${YELLOW}[1/4] 登录管理后台...${NC}"
LOGIN_RESPONSE=$(curl -s -k -X POST "${API_BASE_URL}/admin/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ADMIN_USERNAME}\",\"password\":\"${ADMIN_PASSWORD}\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}登录失败: $LOGIN_RESPONSE${NC}"
    exit 1
fi
echo -e "${GREEN}登录成功${NC}"

# 2. 创建版本
echo -e "${YELLOW}[2/4] 创建版本记录...${NC}"
CREATE_DATA="{
    \"version_name\": \"$VERSION_NAME\",
    \"version_code\": $VERSION_CODE,
    \"platform\": \"$PLATFORM\",
    \"release_notes\": \"$RELEASE_NOTES\",
    \"is_force_update\": $IS_FORCE_UPDATE"

if [ -n "$RELEASE_NOTES_EN" ]; then
    CREATE_DATA="$CREATE_DATA, \"release_notes_en\": \"$RELEASE_NOTES_EN\""
fi

if [ -n "$MIN_SUPPORTED_VERSION" ]; then
    CREATE_DATA="$CREATE_DATA, \"min_supported_version\": \"$MIN_SUPPORTED_VERSION\""
fi

CREATE_DATA="$CREATE_DATA}"

CREATE_RESPONSE=$(curl -s -k -X POST "${API_BASE_URL}/admin/app-versions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CREATE_DATA")

VERSION_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$VERSION_ID" ]; then
    echo -e "${RED}创建版本失败: $CREATE_RESPONSE${NC}"
    exit 1
fi
echo -e "${GREEN}版本创建成功: $VERSION_ID${NC}"

# 3. 上传 APK
echo -e "${YELLOW}[3/4] 上传 APK 文件...${NC}"
UPLOAD_RESPONSE=$(curl -s -k -X POST "${API_BASE_URL}/admin/app-versions/${VERSION_ID}/upload-apk" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@$APK_PATH")

if echo "$UPLOAD_RESPONSE" | grep -q '"message":"APK上传成功"'; then
    FILE_SIZE=$(echo "$UPLOAD_RESPONSE" | grep -o '"size_formatted":"[^"]*"' | cut -d'"' -f4)
    echo -e "${GREEN}APK 上传成功 (${FILE_SIZE})${NC}"
else
    echo -e "${RED}APK 上传失败: $UPLOAD_RESPONSE${NC}"
    exit 1
fi

# 4. 发布版本 (如果指定了 --publish)
if [ "$AUTO_PUBLISH" = "true" ]; then
    echo -e "${YELLOW}[4/4] 发布版本...${NC}"
    PUBLISH_RESPONSE=$(curl -s -k -X POST "${API_BASE_URL}/admin/app-versions/${VERSION_ID}/publish" \
        -H "Authorization: Bearer $TOKEN")

    if echo "$PUBLISH_RESPONSE" | grep -q '"message":"版本已发布"'; then
        echo -e "${GREEN}版本发布成功${NC}"
    else
        echo -e "${RED}版本发布失败: $PUBLISH_RESPONSE${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[4/4] 跳过发布 (使用 --publish 自动发布)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}发布完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "版本 ID: $VERSION_ID"
echo "版本号: $VERSION_NAME+$VERSION_CODE"
if [ "$AUTO_PUBLISH" = "true" ]; then
    echo "状态: 已发布"
else
    echo "状态: 草稿 (请在管理后台手动发布)"
fi

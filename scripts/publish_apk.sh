#!/bin/bash
#
# APK 一键发布脚本
# 用于构建并发布新版本 APK 到服务器
#
# 用法:
#   ./scripts/publish_apk.sh \
#     --version 1.2.2 \
#     --code 19 \
#     --notes "更新说明" \
#     --build \        # 可选：先构建 APK
#     --publish        # 可选：创建后自动发布
#
# 或者指定已构建的 APK:
#   ./scripts/publish_apk.sh \
#     --version 1.2.2 \
#     --code 19 \
#     --apk ./app/build/app/outputs/flutter-apk/app-release.apk \
#     --notes "更新说明"
#
# 环境变量:
#   ADMIN_USERNAME: 管理员用户名 (默认: admin)
#   ADMIN_PASSWORD: 管理员密码 (必需)
#   API_BASE_URL: API 地址 (默认: https://160.202.238.29)
#
# 注意: 构建时会自动添加 --no-tree-shake-icons 参数以避免图标问题
#

set -e

# 默认值
API_BASE_URL="${API_BASE_URL:-https://160.202.238.29}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
PLATFORM="android"
IS_FORCE_UPDATE="false"
DO_BUILD="false"
FLUTTER_CMD="${FLUTTER_CMD:-D:/flutter/bin/flutter}"
APP_DIR="${APP_DIR:-./app}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    echo "APK 一键发布脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --version VERSION   版本号 (如 1.2.2)"
    echo "  --code CODE         构建号 (如 19)"
    echo "  --apk PATH          APK 文件路径 (如不指定则需要 --build)"
    echo "  --build             先构建 APK (使用 --no-tree-shake-icons)"
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
    echo "  FLUTTER_CMD         Flutter 命令路径 (默认: D:/flutter/bin/flutter)"
    echo "  APP_DIR             App 目录 (默认: ./app)"
    echo ""
    echo "示例 (构建并发布):"
    echo "  ADMIN_PASSWORD=xxx ./scripts/publish_apk.sh \\"
    echo "    --version 1.2.2 \\"
    echo "    --code 19 \\"
    echo "    --notes '- 修复若干问题' \\"
    echo "    --build --publish"
    echo ""
    echo "示例 (仅发布已有 APK):"
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
        --build)
            DO_BUILD="true"
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
if [ -z "$VERSION_NAME" ] || [ -z "$VERSION_CODE" ] || [ -z "$RELEASE_NOTES" ]; then
    echo -e "${RED}错误: 缺少必需参数 (--version, --code, --notes)${NC}"
    show_help
    exit 1
fi

# 如果没有指定 APK 路径且没有指定构建，则报错
if [ -z "$APK_PATH" ] && [ "$DO_BUILD" != "true" ]; then
    echo -e "${RED}错误: 请指定 --apk 或使用 --build 构建${NC}"
    show_help
    exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}错误: 请设置 ADMIN_PASSWORD 环境变量${NC}"
    exit 1
fi

# 如果需要构建
if [ "$DO_BUILD" = "true" ]; then
    APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
fi

# 如果不构建，检查 APK 是否存在
if [ "$DO_BUILD" != "true" ] && [ ! -f "$APK_PATH" ]; then
    echo -e "${RED}错误: APK 文件不存在: $APK_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}APK 一键发布脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "版本号: $VERSION_NAME"
echo "构建号: $VERSION_CODE"
echo "构建 APK: $DO_BUILD"
echo "APK 路径: $APK_PATH"
echo "强制更新: $IS_FORCE_UPDATE"
echo "API 地址: $API_BASE_URL"
echo ""

# 计算总步骤数
if [ "$DO_BUILD" = "true" ]; then
    TOTAL_STEPS=5
    STEP=0
else
    TOTAL_STEPS=4
    STEP=0
fi

# 0. 构建 APK (如果需要)
if [ "$DO_BUILD" = "true" ]; then
    STEP=$((STEP + 1))
    echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] 构建 Release APK...${NC}"
    echo "使用 --no-tree-shake-icons 参数避免图标问题"
    echo ""

    # 更新 build_info.dart (同步版本号和构建时间)
    echo "更新 build_info.dart..."
    BUILD_TIME=$(date +"%Y-%m-%dT%H:%M:%S.000000")
    BUILD_TIME_FORMATTED=$(date +"%Y-%m-%d %H:%M:%S")

    cat > "$APP_DIR/lib/core/build_info.dart" << BUILDINFO
/// 自动生成的构建信息 - 请勿手动修改
/// 生成时间: $BUILD_TIME_FORMATTED

class BuildInfo {
  /// 构建时间 (ISO 8601)
  static const String buildTime = '$BUILD_TIME';

  /// 构建时间 (格式化显示)
  static const String buildTimeFormatted = '$BUILD_TIME_FORMATTED';

  /// 版本号
  static const String version = '$VERSION_NAME';

  /// 构建号
  static const int buildNumber = $VERSION_CODE;

  /// 完整版本
  static const String fullVersion = '$VERSION_NAME+$VERSION_CODE';

  /// 构建类型 (Debug/Release)
  static const String buildType = 'Release';

  /// 带类型的完整版本号
  static const String displayVersion = '$VERSION_NAME';
}
BUILDINFO
    echo -e "${GREEN}✓ 已更新 build_info.dart${NC}"

    # 进入 app 目录构建
    pushd "$APP_DIR" > /dev/null

    # 清理并构建
    "$FLUTTER_CMD" clean
    "$FLUTTER_CMD" pub get
    "$FLUTTER_CMD" build apk --release --no-tree-shake-icons

    popd > /dev/null

    # 检查构建结果
    if [ ! -f "$APK_PATH" ]; then
        echo -e "${RED}构建失败: APK 文件不存在${NC}"
        exit 1
    fi

    APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
    echo -e "${GREEN}构建成功: $APK_PATH ($APK_SIZE)${NC}"
    echo ""
fi

# 1. 登录获取 Token
STEP=$((STEP + 1))
echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] 登录管理后台...${NC}"
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
STEP=$((STEP + 1))
echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] 创建版本记录...${NC}"

# 使用 Node.js 构建 JSON，确保中文字符正确编码
CREATE_DATA=$(node -e "
const data = {
    version_name: '$VERSION_NAME',
    version_code: $VERSION_CODE,
    platform: '$PLATFORM',
    release_notes: '$RELEASE_NOTES',
    is_force_update: $IS_FORCE_UPDATE
};
if ('$RELEASE_NOTES_EN') data.release_notes_en = '$RELEASE_NOTES_EN';
if ('$MIN_SUPPORTED_VERSION') data.min_supported_version = '$MIN_SUPPORTED_VERSION';
console.log(JSON.stringify(data));
")

CREATE_RESPONSE=$(curl -s -k -X POST "${API_BASE_URL}/admin/app-versions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json; charset=utf-8" \
    -d "$CREATE_DATA")

VERSION_ID=$(echo "$CREATE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$VERSION_ID" ]; then
    echo -e "${RED}创建版本失败: $CREATE_RESPONSE${NC}"
    exit 1
fi
echo -e "${GREEN}版本创建成功: $VERSION_ID${NC}"

# 3. 上传 APK
STEP=$((STEP + 1))
echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] 上传 APK 文件...${NC}"
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
STEP=$((STEP + 1))
if [ "$AUTO_PUBLISH" = "true" ]; then
    echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] 发布版本...${NC}"
    PUBLISH_RESPONSE=$(curl -s -k -X POST "${API_BASE_URL}/admin/app-versions/${VERSION_ID}/publish" \
        -H "Authorization: Bearer $TOKEN")

    if echo "$PUBLISH_RESPONSE" | grep -q '"message":"版本已发布"'; then
        echo -e "${GREEN}版本发布成功${NC}"
    else
        echo -e "${RED}版本发布失败: $PUBLISH_RESPONSE${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}[$STEP/$TOTAL_STEPS] 跳过发布 (使用 --publish 自动发布)${NC}"
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

#!/bin/bash
# 快速构建和发布脚本
# 用法: ./quick_build.sh

set -e  # 遇到错误立即退出

echo "=========================================="
echo "AI智能记账 - 快速构建脚本"
echo "版本: 2.0.3 (Build 43)"
echo "=========================================="
echo ""

# 切换到app目录
cd "$(dirname "$0")/app"

echo "📦 步骤1: 清理之前的构建..."
flutter clean

echo ""
echo "📥 步骤2: 获取依赖..."
flutter pub get

echo ""
echo "🔨 步骤3: 构建Release APK..."
echo "  (这可能需要几分钟时间...)"
flutter build apk --release

echo ""
echo "✅ 构建完成！"
echo ""
echo "APK位置:"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
FULL_PATH="$(pwd)/$APK_PATH"

if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(ls -lh "$APK_PATH" | awk '{print $5}')
    echo "  📱 $FULL_PATH"
    echo "  📏 大小: $APK_SIZE"
    echo ""

    # 显示APK信息
    if command -v aapt &> /dev/null; then
        echo "APK信息:"
        aapt dump badging "$APK_PATH" | grep -E "package:|versionCode|versionName" | head -3
        echo ""
    fi

    echo "=========================================="
    echo "下一步操作："
    echo "=========================================="
    echo ""
    echo "1️⃣  测试APK (可选):"
    echo "   adb install -r \"$FULL_PATH\""
    echo ""
    echo "2️⃣  发布新版本:"
    echo "   cd .."
    echo "   python3 scripts/publish_version.py \\"
    echo "     \"$FULL_PATH\" \\"
    echo "     --version 2.0.3 \\"
    echo "     --code 43 \\"
    echo "     --release-notes RELEASE_NOTES_2.0.3.md"
    echo ""
    echo "   # 如果有旧版本APK，添加这些参数生成增量补丁:"
    echo "   #   --previous-apk ./dist/ai_bookkeeping_2.0.2.apk \\"
    echo "   #   --previous-version 2.0.2 \\"
    echo "   #   --previous-code 42"
    echo ""
    echo "3️⃣  上传到服务器并通过管理后台创建版本记录"
    echo ""
    echo "=========================================="
else
    echo "❌ 错误: 找不到APK文件"
    exit 1
fi

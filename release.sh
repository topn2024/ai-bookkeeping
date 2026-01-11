#!/bin/bash
# 一键发布脚本快捷方式
# 用法: ./release.sh

set -e

# 从pubspec.yaml读取版本信息
VERSION=$(grep '^version:' app/pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)
CODE=$(grep '^version:' app/pubspec.yaml | awk '{print $2}' | cut -d'+' -f2)

echo "========================================"
echo "一键发布 AI智能记账"
echo "========================================"
echo "版本: $VERSION (Build $CODE)"
echo ""

# 提示用户确认
read -p "确认发布此版本? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消发布"
    exit 1
fi

# 询问是否有旧版本（用于生成补丁）
echo ""
read -p "是否有旧版本用于生成增量补丁? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "请输入旧版本名称 (例如 2.0.2): " OLD_VERSION
    read -p "请输入旧版本号 (例如 42): " OLD_CODE

    # 检查旧版本APK是否存在
    OLD_APK="dist/ai_bookkeeping_${OLD_VERSION}.apk"
    if [ ! -f "$OLD_APK" ]; then
        echo "警告: 找不到旧版本APK: $OLD_APK"
        echo "将跳过补丁生成"
        OLD_VERSION=""
    fi
fi

# 询问服务器地址
echo ""
read -p "服务器地址 (默认: http://localhost:8000): " BASE_URL
BASE_URL=${BASE_URL:-http://localhost:8000}

# 询问是否强制更新
echo ""
read -p "是否强制更新? (y/N) " -n 1 -r
echo
FORCE_FLAG=""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    FORCE_FLAG="--force-update"
fi

# 构建命令
CMD="python3 auto_release.py --version $VERSION --code $CODE --base-url $BASE_URL"

if [ -n "$OLD_VERSION" ]; then
    CMD="$CMD --previous-version $OLD_VERSION --previous-code $OLD_CODE"
fi

if [ -n "$FORCE_FLAG" ]; then
    CMD="$CMD $FORCE_FLAG"
fi

# 检查是否有发布说明文件
RELEASE_NOTES="RELEASE_NOTES_${VERSION}.md"
if [ -f "$RELEASE_NOTES" ]; then
    CMD="$CMD --release-notes $RELEASE_NOTES"
    echo "使用发布说明: $RELEASE_NOTES"
fi

# 执行发布
echo ""
echo "开始发布..."
echo ""
eval $CMD

# 如果成功，保存APK到dist目录
if [ $? -eq 0 ]; then
    mkdir -p dist
    cp app/build/app/outputs/flutter-apk/app-release.apk "dist/ai_bookkeeping_${VERSION}.apk"
    echo ""
    echo "APK已保存到: dist/ai_bookkeeping_${VERSION}.apk"
fi

#!/bin/bash
# Release 构建脚本
# 确保 Dart 代码混淆始终启用，防止 secrets.dart 中的密钥被反编译提取
#
# 用法:
#   ./scripts/build_release.sh apk          # 构建 APK
#   ./scripts/build_release.sh appbundle    # 构建 AAB (Google Play)
#   ./scripts/build_release.sh ios          # 构建 iOS
#   ./scripts/build_release.sh ipa          # 构建 IPA

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
DEBUG_INFO_DIR="$APP_DIR/build/debug-info"

# 默认构建 APK
BUILD_TARGET="${1:-apk}"

# 确保 debug-info 目录存在
mkdir -p "$DEBUG_INFO_DIR"

echo "=== Flutter Release Build ==="
echo "Target: $BUILD_TARGET"
echo "Obfuscation: ENABLED"
echo "Debug info: $DEBUG_INFO_DIR"
echo ""

cd "$APP_DIR"

# 更新构建信息
if [ -f "scripts/update_build_info.dart" ]; then
  dart run scripts/update_build_info.dart --build-type=release 2>/dev/null || true
fi

case "$BUILD_TARGET" in
  apk)
    flutter build apk --release \
      --obfuscate \
      --split-debug-info="$DEBUG_INFO_DIR"
    echo ""
    echo "APK 输出: build/app/outputs/flutter-apk/app-release.apk"
    ;;
  appbundle|aab)
    flutter build appbundle --release \
      --obfuscate \
      --split-debug-info="$DEBUG_INFO_DIR"
    echo ""
    echo "AAB 输出: build/app/outputs/bundle/release/app-release.aab"
    ;;
  ios)
    flutter build ios --release \
      --obfuscate \
      --split-debug-info="$DEBUG_INFO_DIR"
    echo ""
    echo "iOS build 完成"
    ;;
  ipa)
    flutter build ipa --release \
      --obfuscate \
      --split-debug-info="$DEBUG_INFO_DIR"
    echo ""
    echo "IPA 输出: build/ios/ipa/"
    ;;
  *)
    echo "未知构建目标: $BUILD_TARGET"
    echo "用法: $0 {apk|appbundle|ios|ipa}"
    exit 1
    ;;
esac

echo ""
echo "=== 构建完成 ==="
echo "重要: debug-info 文件保存在 $DEBUG_INFO_DIR"
echo "       用于崩溃日志符号化还原，请妥善保管"

#!/bin/bash
# 发布 v2.0.5 版本
# 语音交互增强、密码安全改进、导航优化

set -e

# 配置
VERSION="2.0.5"
CODE="45"
NOTES="优化语音助手界面和识别引擎，完善密码找回流程，改进主导航栏交互，升级分析中心数据展示，提升应用整体稳定性"

# 从环境变量读取配置，或使用默认值
API_BASE_URL="${API_BASE_URL:-http://160.202.238.29}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

echo "=========================================="
echo "发布 AI智能记账 v${VERSION}"
echo "=========================================="
echo ""
echo "版本: ${VERSION}"
echo "Build: ${CODE}"
echo "服务器: ${API_BASE_URL}"
echo ""

# 使用现有的发布脚本
./scripts/publish_apk.sh \
  --version "$VERSION" \
  --code "$CODE" \
  --notes "$NOTES" \
  --build \
  --publish

echo ""
echo "=========================================="
echo "✅ 发布完成！"
echo "=========================================="
echo ""
echo "版本 ${VERSION}+${CODE} 已成功发布到服务器"
echo "用户可以通过应用内更新功能获取新版本"
echo ""

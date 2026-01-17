#!/bin/bash
# 发布 v2.0.6 版本
# 实现交互式页面引导功能

set -e

# 配置
VERSION="2.0.6"
CODE="48"
NOTES="实现交互式页面引导功能

新增三步引导流程，在用户首次打开应用时自动展示：
1. 💡 数据下钻 - 介绍所有汇总数据支持点击查看详情
2. 🎤 语音操控 - 介绍语音记账和查询功能
3. 🐾 小记助手 - 介绍操作记录和对话历史

技术特点：
• 使用Overlay遮罩层+CustomPainter实现高亮挖洞效果
• 通过GlobalKey精确定位目标UI元素
• 支持脉冲动画和平滑过渡
• 使用SharedPreferences记录引导完成状态
• 毛玻璃风格提示卡片，与应用设计一致"

# 从环境变量读取配置，或使用默认值
API_BASE_URL="${API_BASE_URL:-https://39.105.12.124}"
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
ADMIN_PASSWORD="$ADMIN_PASSWORD" FLUTTER_CMD="flutter" ./scripts/publish_apk.sh \
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

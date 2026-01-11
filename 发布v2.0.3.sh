#!/bin/bash
# 发布 v2.0.3 版本
# 修复密码找回邮件发送问题

set -e

# 配置
VERSION="2.0.3"
CODE="43"
NOTES="- 修复密码找回邮件发送问题
- 现在会真正发送包含6位验证码的邮件
- 验证码有效期10分钟"

# 从环境变量读取配置，或使用默认值
API_BASE_URL="${API_BASE_URL:-http://160.202.238.29}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"

echo "=========================================="
echo "发布 AI智能记账 v${VERSION}"
echo "=========================================="
echo ""
echo "版本: ${VERSION}"
echo "Build: ${CODE}"
echo "服务器: ${API_BASE_URL}"
echo ""

# 检查管理员密码
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "请输入管理员密码:"
    read -s ADMIN_PASSWORD
    export ADMIN_PASSWORD
    echo ""
fi

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

#!/bin/bash
# 统一发布到两台服务器
# v2.0.11 - 零基预算与小金库整合，首页刷新与支出自动同步

set -e

# 配置
VERSION="2.0.11"
CODE="55"
NOTES="零基预算与小金库整合，首页刷新与支出自动同步

主要更新：
1. 统一零基预算与小金库架构
   - 移除双系统映射逻辑，直接使用BudgetVault
   - 智能分配结果自动同步小金库：删除多余、创建缺失、更新现有
   - 修复智能分配算法，确保分配总额不超过收入

2. 首页下拉刷新功能
   - 添加RefreshIndicator支持下拉刷新
   - 自动刷新交易记录和小金库数据

3. 小金库支出自动统计
   - 从本月交易记录自动计算实际支出
   - 智能分类匹配：英文ID转中文，语义匹配（餐饮→外卖/饮品，交通→公交/停车等）
   - 实时同步到小金库spentAmount

4. 小金库列表优化
   - 显示使用率而非达成率
   - 颜色指示：绿色(0-50%)、蓝色(50-80%)、橙色(80-100%)、红色(超支)
   - 超支小金库显示红色标签和超支金额

5. 财务健康评估完善
   - 为5个维度添加详细评分说明页面
   - 提供改进建议和评分规则说明

技术改进：
• 优化智能分配按比例分配剩余金额
• 小金库支出统计支持完全匹配和语义匹配
• 修复小金库列表显示逻辑错误"

# 服务器配置
SERVER1_URL="https://160.202.238.29"
SERVER2_URL="https://39.105.12.124"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

echo "=========================================="
echo "统一发布 AI智能记账 v${VERSION}+${CODE}"
echo "=========================================="
echo ""
echo "版本: ${VERSION}"
echo "Build: ${CODE}"
echo "目标服务器:"
echo "  - 服务器1: ${SERVER1_URL}"
echo "  - 服务器2: ${SERVER2_URL}"
echo ""

# 询问确认
read -p "确认发布到两台服务器？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "发布已取消"
    exit 1
fi

# 1. 构建APK
echo ""
echo "=========================================="
echo "[1/4] 构建 Release APK"
echo "=========================================="
cd app
flutter clean
flutter pub get
flutter build apk --release --no-tree-shake-icons
cd ..

APK_PATH="app/build/app/outputs/flutter-apk/app-release.apk"

if [ ! -f "$APK_PATH" ]; then
    echo "❌ APK构建失败"
    exit 1
fi

APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
echo "✓ APK构建成功: $APK_SIZE"

# 2. 发布到服务器1 (160.202.238.29)
echo ""
echo "=========================================="
echo "[2/4] 发布到服务器1: 160.202.238.29"
echo "=========================================="

API_BASE_URL="$SERVER1_URL" \
ADMIN_PASSWORD="$ADMIN_PASSWORD" \
FLUTTER_CMD="flutter" \
./scripts/publish_apk.sh \
  --version "$VERSION" \
  --code "$CODE" \
  --notes "$NOTES" \
  --apk "$APK_PATH" \
  --publish

if [ $? -eq 0 ]; then
    echo "✓ 服务器1发布成功"
    SERVER1_SUCCESS=true
else
    echo "❌ 服务器1发布失败"
    SERVER1_SUCCESS=false
fi

# 3. 发布到服务器2 (39.105.12.124)
echo ""
echo "=========================================="
echo "[3/4] 发布到服务器2: 39.105.12.124"
echo "=========================================="

API_BASE_URL="$SERVER2_URL" \
ADMIN_PASSWORD="$ADMIN_PASSWORD" \
FLUTTER_CMD="flutter" \
./scripts/publish_apk.sh \
  --version "$VERSION" \
  --code "$CODE" \
  --notes "$NOTES" \
  --apk "$APK_PATH" \
  --publish

if [ $? -eq 0 ]; then
    echo "✓ 服务器2发布成功"
    SERVER2_SUCCESS=true
else
    echo "❌ 服务器2发布失败"
    SERVER2_SUCCESS=false
fi

# 4. 验证版本一致性
echo ""
echo "=========================================="
echo "[4/4] 验证版本一致性"
echo "=========================================="

echo "检查服务器1..."
VERSION1=$(curl -s "${SERVER1_URL}/admin/app-versions/latest" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{data['version_name']}+{data['version_code']}\")" 2>/dev/null || echo "检查失败")
echo "  版本: $VERSION1"

echo ""
echo "检查服务器2..."
VERSION2=$(curl -k -s "${SERVER2_URL}/admin/app-versions/latest" 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{data['version_name']}+{data['version_code']}\")" 2>/dev/null || echo "检查失败")
echo "  版本: $VERSION2"

echo ""
echo "=========================================="
echo "📊 发布结果汇总"
echo "=========================================="
echo ""
echo "服务器1 (160.202.238.29):"
if [ "$SERVER1_SUCCESS" = true ]; then
    echo "  ✓ 发布成功"
    echo "  版本: $VERSION1"
else
    echo "  ❌ 发布失败"
fi

echo ""
echo "服务器2 (39.105.12.124):"
if [ "$SERVER2_SUCCESS" = true ]; then
    echo "  ✓ 发布成功"
    echo "  版本: $VERSION2"
else
    echo "  ❌ 发布失败"
fi

echo ""
if [ "$VERSION1" = "$VERSION2" ] && [ "$VERSION1" = "${VERSION}+${CODE}" ]; then
    echo "✓ 版本一致性检查通过"
    echo ""
    echo "=========================================="
    echo "🎉 统一发布完成！"
    echo "=========================================="
    echo ""
    echo "版本 ${VERSION}+${CODE} 已成功发布到两台服务器"
    echo "用户可以通过应用内更新功能获取新版本"
    exit 0
else
    echo "⚠️  警告: 版本可能不一致"
    echo ""
    echo "请手动检查并解决问题"
    exit 1
fi

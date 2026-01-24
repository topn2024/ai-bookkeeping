#!/bin/bash
# 数据库重置快捷脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "🔧 AI记账 - 数据库重置工具"
echo ""
echo "⚠️  警告：此脚本会删除所有表并重新创建！"
echo ""
echo "请选择重置模式："
echo "  1) clean - 仅重建表结构"
echo "  2) init  - 重建表并初始化系统数据（推荐）"
echo "  3) full  - 完整重置（含测试数据）"
echo ""
read -p "请输入选项 (1-3): " choice

case $choice in
    1)
        mode="clean"
        ;;
    2)
        mode="init"
        ;;
    3)
        mode="full"
        ;;
    *)
        echo "❌ 无效选项"
        exit 1
        ;;
esac

echo ""
echo "执行模式: $mode"
echo ""

# 检查虚拟环境
if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# 执行重置脚本
python3 scripts/reset_database.py --mode "$mode"

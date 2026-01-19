#!/bin/bash

# SVG转PNG批量转换脚本
# 要求: 300 DPI, PNG格式

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATENTS_DIR="$(dirname "$SCRIPT_DIR")/patents"

echo "开始转换SVG图片为PNG格式..."
echo "目标目录: $PATENTS_DIR"
echo ""

# 统计
total=0
success=0
failed=0

# 查找所有SVG文件
while IFS= read -r svg_file; do
    total=$((total + 1))

    # 生成PNG文件名
    png_file="${svg_file%.svg}.png"

    # 显示进度
    echo "[$total] 转换: $(basename "$svg_file")"

    # 转换SVG为PNG (300 DPI)
    if rsvg-convert -d 300 -p 300 "$svg_file" -o "$png_file" 2>/dev/null; then
        success=$((success + 1))
        echo "  ✓ 成功: $png_file"
    else
        failed=$((failed + 1))
        echo "  ✗ 失败: $svg_file"
    fi

done < <(find "$PATENTS_DIR" -name "*.svg" -type f)

echo ""
echo "转换完成!"
echo "总计: $total 个文件"
echo "成功: $success 个"
echo "失败: $failed 个"

if [ $failed -eq 0 ]; then
    echo ""
    echo "✅ 所有图片转换成功!"
else
    echo ""
    echo "⚠️  部分图片转换失败，请检查错误信息"
    exit 1
fi

#!/bin/bash

# 专利文档批量转换脚本
# 功能：将Markdown格式的专利文档转换为Word格式
# 作者：AI Assistant
# 日期：2026-01-19

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置
PATENTS_DIR="/Users/beihua/code/baiji/ai-bookkeeping/docs/patents/patents"
OUTPUT_DIR="/Users/beihua/code/baiji/ai-bookkeeping/docs/patents/output"

# 检查Pandoc是否安装
check_pandoc() {
    if ! command -v pandoc &> /dev/null; then
        echo -e "${RED}错误: 未安装Pandoc${NC}"
        echo "请先安装Pandoc:"
        echo "  macOS: brew install pandoc"
        echo "  或访问: https://pandoc.org/installing.html"
        exit 1
    fi
    echo -e "${GREEN}✓ Pandoc已安装${NC}"
}

# 创建输出目录
create_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        echo -e "${GREEN}✓ 创建输出目录: $OUTPUT_DIR${NC}"
    fi
}

# 转换单个专利
convert_patent() {
    local patent_dir=$1
    local patent_name=$(basename "$patent_dir")

    echo -e "${YELLOW}转换 $patent_name...${NC}"

    local output_patent_dir="$OUTPUT_DIR/$patent_name"
    mkdir -p "$output_patent_dir"

    local converted=0

    # 转换权利要求书
    if [ -f "$patent_dir/claims.md" ]; then
        pandoc "$patent_dir/claims.md" \
            -o "$output_patent_dir/${patent_name}-权利要求书.docx" \
            --from=markdown \
            --to=docx
        echo -e "  ${GREEN}✓ 权利要求书${NC}"
        ((converted++))
    else
        echo -e "  ${RED}✗ 权利要求书不存在${NC}"
    fi

    # 转换说明书
    if [ -f "$patent_dir/specification.md" ]; then
        pandoc "$patent_dir/specification.md" \
            -o "$output_patent_dir/${patent_name}-说明书.docx" \
            --from=markdown \
            --to=docx
        echo -e "  ${GREEN}✓ 说明书${NC}"
        ((converted++))
    else
        echo -e "  ${RED}✗ 说明书不存在${NC}"
    fi

    # 转换摘要
    if [ -f "$patent_dir/abstract.md" ]; then
        pandoc "$patent_dir/abstract.md" \
            -o "$output_patent_dir/${patent_name}-摘要.docx" \
            --from=markdown \
            --to=docx
        echo -e "  ${GREEN}✓ 摘要${NC}"
        ((converted++))
    else
        echo -e "  ${RED}✗ 摘要不存在${NC}"
    fi

    return $converted
}

# 主函数
main() {
    echo "=========================================="
    echo "专利文档批量转换工具"
    echo "=========================================="
    echo ""

    # 检查Pandoc
    check_pandoc
    echo ""

    # 创建输出目录
    create_output_dir
    echo ""

    # 统计
    local total_patents=0
    local total_files=0

    # 遍历所有专利目录
    for patent_dir in "$PATENTS_DIR"/P*; do
        if [ -d "$patent_dir" ]; then
            ((total_patents++))
            convert_patent "$patent_dir"
            local files_converted=$?
            ((total_files+=files_converted))
            echo ""
        fi
    done

    # 输出统计
    echo "=========================================="
    echo -e "${GREEN}转换完成！${NC}"
    echo "转换专利数: $total_patents"
    echo "转换文件数: $total_files"
    echo "输出目录: $OUTPUT_DIR"
    echo "=========================================="
    echo ""
    echo "下一步:"
    echo "1. 打开输出目录查看转换后的Word文档"
    echo "2. 手动调整格式（页边距、字体、行距）"
    echo "3. 检查内容完整性"
    echo "4. 准备附图文件"
    echo "5. 填写专利申请请求书"
}

# 运行主函数
main

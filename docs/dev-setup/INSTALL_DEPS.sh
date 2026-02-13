#!/bin/bash
# 安装发布脚本依赖

echo "检查Python环境..."

# 检查requests
if python3 -c "import requests" 2>/dev/null; then
    echo "✓ requests 已安装"
else
    echo "× requests 未安装"
    echo "  安装: pip3 install --user requests"
    pip3 install --user requests
fi

# 检查bsdiff4
if python3 -c "import bsdiff4" 2>/dev/null; then
    echo "✓ bsdiff4 已安装"
else
    echo "× bsdiff4 未安装"
    echo "  安装: pip3 install --user bsdiff4"
    pip3 install --user bsdiff4
fi

echo ""
echo "依赖检查完成！"
echo ""
echo "现在可以运行发布脚本:"
echo "  ./release.sh"
echo "或"
echo "  python3 auto_release.py --version 2.0.3 --code 43"

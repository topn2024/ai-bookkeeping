#!/bin/bash
# Admin Web 前端部署脚本

set -e

# 配置
SERVER="160.202.238.29"
USER="root"
REMOTE_DIR="/var/www/admin"
LOCAL_DIST="./dist"

echo "========================================="
echo "Admin Web 前端部署"
echo "========================================="
echo ""

# 检查 dist 目录
if [ ! -d "$LOCAL_DIST" ]; then
    echo "错误: dist 目录不存在，请先运行 npm run build"
    exit 1
fi

echo "📦 构建信息:"
echo "- 本地构建目录: $LOCAL_DIST"
echo "- 服务器: $SERVER"
echo "- 远程目录: $REMOTE_DIR"
echo ""

# 询问确认
read -p "是否继续部署？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "部署已取消"
    exit 1
fi

echo ""
echo "[1/3] 创建远程目录..."
ssh $USER@$SERVER "mkdir -p $REMOTE_DIR && mkdir -p $REMOTE_DIR.backup"

echo "[2/3] 备份现有文件..."
ssh $USER@$SERVER "if [ -d $REMOTE_DIR/assets ]; then rm -rf $REMOTE_DIR.backup/* && cp -r $REMOTE_DIR/* $REMOTE_DIR.backup/; fi"

echo "[3/3] 上传新文件..."
rsync -avz --delete $LOCAL_DIST/ $USER@$SERVER:$REMOTE_DIR/

echo ""
echo "========================================="
echo "✅ 部署完成！"
echo "========================================="
echo ""
echo "现在需要配置 Nginx:"
echo ""
echo "1. SSH 到服务器: ssh $USER@$SERVER"
echo "2. 编辑 Nginx 配置: vim /etc/nginx/sites-available/ai-bookkeeping"
echo "3. 添加以下配置:"
echo ""
echo "    location /admin {"
echo "        alias /var/www/admin;"
echo "        try_files \$uri \$uri/ /admin/index.html;"
echo "        index index.html;"
echo "    }"
echo ""
echo "4. 重载 Nginx: systemctl reload nginx"
echo "5. 访问管理界面: https://160.202.238.29/admin"
echo ""

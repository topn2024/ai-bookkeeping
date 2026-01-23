#!/bin/bash
# Admin Web 前端部署脚本 - 部署到 39.105.12.124
# 使用方法: ./deploy-to-39.sh

set -e

# 配置
SERVER="39.105.12.124"
USER="root"
REMOTE_DIR="/var/www/admin-web"
LOCAL_DIST="./dist"

echo "========================================="
echo "Admin Web 前端部署到 $SERVER"
echo "========================================="
echo ""

# 检查 dist 目录
if [ ! -d "$LOCAL_DIST" ]; then
    echo "错误: dist 目录不存在，正在构建..."
    npm run build
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
echo "[1/4] 创建远程目录..."
ssh $USER@$SERVER "mkdir -p $REMOTE_DIR && mkdir -p $REMOTE_DIR.backup"

echo "[2/4] 备份现有文件..."
ssh $USER@$SERVER "if [ -d $REMOTE_DIR/assets ]; then rm -rf $REMOTE_DIR.backup/* && cp -r $REMOTE_DIR/* $REMOTE_DIR.backup/; fi"

echo "[3/4] 上传新文件..."
rsync -avz --delete $LOCAL_DIST/ $USER@$SERVER:$REMOTE_DIR/

echo "[4/4] 配置防火墙和Nginx..."
ssh $USER@$SERVER << 'ENDSSH'
# 开放443端口
echo "开放443端口..."
if command -v ufw &> /dev/null; then
    ufw allow 443/tcp
    ufw reload
elif command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --reload
else
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    service iptables save 2>/dev/null || true
fi

# 检查nginx配置
echo "检查Nginx配置..."
if ! grep -q "location /admin-web" /etc/nginx/sites-available/ai-bookkeeping* /etc/nginx/conf.d/*.conf 2>/dev/null; then
    echo "警告: 未找到 /admin-web 的 nginx 配置"
    echo "需要手动添加nginx配置"
fi

# 重载nginx
nginx -t && systemctl reload nginx
echo "Nginx 已重载"

ENDSSH

echo ""
echo "========================================="
echo "✅ 部署完成！"
echo "========================================="
echo ""
echo "访问地址: https://$SERVER/admin-web/"
echo ""
echo "如果仍然无法访问，请检查："
echo "1. 阿里云/腾讯云安全组是否开放443端口"
echo "2. Nginx配置是否正确"
echo "3. SSL证书是否有效"
echo ""

#!/bin/bash
# 部署静态页面到服务器
# 用法: ./deploy_static.sh [server_ip]

set -e

SERVER_IP="${1:-39.105.12.124}"
REMOTE_USER="root"
REMOTE_DIR="/home/ai-bookkeeping/static"
LOCAL_DIR="$(dirname "$0")/../static"

echo "=== 部署静态页面到 $SERVER_IP ==="

# 创建远程目录
ssh "$REMOTE_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"

# 上传文件
scp "$LOCAL_DIR"/*.html "$REMOTE_USER@$SERVER_IP:$REMOTE_DIR/"

echo "=== 文件已上传 ==="

# 重载 Nginx
ssh "$REMOTE_USER@$SERVER_IP" "nginx -t && nginx -s reload"

echo "=== Nginx 已重载 ==="
echo ""
echo "隐私政策: https://$SERVER_IP/legal/privacy-policy.html"
echo "隐私权利: https://$SERVER_IP/legal/privacy-rights.html"

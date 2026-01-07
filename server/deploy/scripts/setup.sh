#!/bin/bash
# ==============================================================================
# AI Bookkeeping - 服务器初始化脚本
# ==============================================================================
# 在新服务器上执行此脚本完成初始配置
# 使用方式: sudo ./setup.sh
# ==============================================================================

set -e

# 配置
APP_USER="ai-bookkeeping"
APP_DIR="/home/${APP_USER}/app"
VENV_DIR="/home/${APP_USER}/venv"

echo "========================================"
echo "  AI Bookkeeping 服务器初始化"
echo "========================================"

# 检查 root 权限
if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 用户执行此脚本"
    exit 1
fi

# 1. 创建应用用户
echo "[1/8] 创建应用用户..."
if ! id "$APP_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$APP_USER"
    echo "用户 $APP_USER 已创建"
else
    echo "用户 $APP_USER 已存在"
fi

# 2. 安装系统依赖
echo "[2/8] 安装系统依赖..."
apt-get update
apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    nginx \
    postgresql-client \
    git \
    curl \
    vim \
    htop

# 3. 创建目录结构
echo "[3/8] 创建目录结构..."
mkdir -p "$APP_DIR"
mkdir -p "/home/${APP_USER}/backups"
mkdir -p "/home/${APP_USER}/logs"
mkdir -p "/var/log/ai-bookkeeping"
chown -R "$APP_USER:$APP_USER" "/home/${APP_USER}"
chown -R "$APP_USER:$APP_USER" "/var/log/ai-bookkeeping"

# 4. 创建 Python 虚拟环境
echo "[4/8] 创建 Python 虚拟环境..."
if [ ! -d "$VENV_DIR" ]; then
    sudo -u "$APP_USER" python3.11 -m venv "$VENV_DIR"
    echo "虚拟环境已创建: $VENV_DIR"
fi

# 5. 安装 systemd 服务
echo "[5/8] 安装 systemd 服务..."

# API 服务模板
cat > /etc/systemd/system/ai-bookkeeping-api@.service << 'EOF'
[Unit]
Description=AI Bookkeeping API Server (Port %i)
After=network.target postgresql.service redis.service

[Service]
Type=exec
User=ai-bookkeeping
Group=ai-bookkeeping
WorkingDirectory=/home/ai-bookkeeping/app/server
EnvironmentFile=/home/ai-bookkeeping/app/server/.env
ExecStart=/home/ai-bookkeeping/venv/bin/uvicorn \
    app.main:app \
    --host 127.0.0.1 \
    --port %i \
    --workers 2 \
    --loop uvloop \
    --http httptools
ExecStop=/bin/kill -s TERM $MAINPID
TimeoutStopSec=30
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Admin 服务
cat > /etc/systemd/system/ai-bookkeeping-admin.service << 'EOF'
[Unit]
Description=AI Bookkeeping Admin API Server
After=network.target postgresql.service ai-bookkeeping-api@8000.service

[Service]
Type=exec
User=ai-bookkeeping
Group=ai-bookkeeping
WorkingDirectory=/home/ai-bookkeeping/app/server
EnvironmentFile=/home/ai-bookkeeping/app/server/.env
ExecStart=/home/ai-bookkeeping/venv/bin/uvicorn \
    admin.main:app \
    --host 127.0.0.1 \
    --port 8002 \
    --workers 1
ExecStop=/bin/kill -s TERM $MAINPID
TimeoutStopSec=30
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
echo "systemd 服务已安装"

# 6. 配置 Nginx
echo "[6/8] 配置 Nginx..."

# 创建 SSL 目录
mkdir -p /etc/nginx/ssl

# 生成自签名证书（生产环境应使用 Let's Encrypt）
if [ ! -f /etc/nginx/ssl/server.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/server.key \
        -out /etc/nginx/ssl/server.crt \
        -subj "/C=CN/ST=Beijing/L=Beijing/O=AI-Bookkeeping/CN=localhost"
    echo "自签名 SSL 证书已生成"
fi

# 复制 Nginx 配置（如果存在）
if [ -f "${APP_DIR}/server/deploy/nginx/ai-bookkeeping.conf" ]; then
    cp "${APP_DIR}/server/deploy/nginx/ai-bookkeeping.conf" /etc/nginx/sites-available/
    ln -sf /etc/nginx/sites-available/ai-bookkeeping.conf /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
fi

# 7. 配置日志轮转
echo "[7/8] 配置日志轮转..."
cat > /etc/logrotate.d/ai-bookkeeping << 'EOF'
/var/log/ai-bookkeeping/*.log
/home/ai-bookkeeping/app/server/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 ai-bookkeeping ai-bookkeeping
    sharedscripts
    postrotate
        systemctl reload ai-bookkeeping-api@8000 2>/dev/null || true
    endscript
}

/var/log/nginx/ai-bookkeeping-*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -s /run/nginx.pid ] && kill -USR1 $(cat /run/nginx.pid)
    endscript
}
EOF

# 8. 设置防火墙
echo "[8/8] 配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 22/tcp
    echo "UFW 规则已添加"
fi

echo ""
echo "========================================"
echo "  初始化完成!"
echo "========================================"
echo ""
echo "后续步骤:"
echo "1. 克隆代码到 ${APP_DIR}:"
echo "   sudo -u ${APP_USER} git clone https://github.com/topn2024/ai-bookkeeping.git ${APP_DIR}"
echo ""
echo "2. 配置环境变量:"
echo "   cp ${APP_DIR}/server/.env.example ${APP_DIR}/server/.env"
echo "   vim ${APP_DIR}/server/.env"
echo ""
echo "3. 安装 Python 依赖:"
echo "   sudo -u ${APP_USER} ${VENV_DIR}/bin/pip install -r ${APP_DIR}/server/requirements.txt"
echo ""
echo "4. 启动服务:"
echo "   systemctl enable ai-bookkeeping-api@8000"
echo "   systemctl enable ai-bookkeeping-admin"
echo "   systemctl start ai-bookkeeping-api@8000"
echo "   systemctl start ai-bookkeeping-admin"
echo ""
echo "5. 检查服务状态:"
echo "   systemctl status ai-bookkeeping-api@8000"
echo "   curl http://127.0.0.1:8000/health"
echo ""

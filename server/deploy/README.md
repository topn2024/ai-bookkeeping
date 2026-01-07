# AI Bookkeeping 部署指南

## 架构概览

```
                         Internet
                            │
                      ┌─────┴─────┐
                      │   Nginx   │
                      │  :80/:443 │
                      └─────┬─────┘
                            │
           ┌────────────────┼────────────────┐
           │                │                │
           ▼                ▼                ▼
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │  API :8000  │  │  API :8001  │  │ Admin :8002 │
    │   (主实例)   │  │   (备份)    │  │             │
    └──────┬──────┘  └──────┬──────┘  └──────┬──────┘
           │                │                │
           └────────────────┼────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │PostgreSQL│  │  Redis   │  │  MinIO   │
        │  :5432   │  │  :6379   │  │  :9000   │
        └──────────┘  └──────────┘  └──────────┘
```

## 零停机部署原理

### 滚动更新流程

```
时间线
  │
  ├─ T0: 当前状态
  │      nginx → API:8000 (活跃)
  │               API:8001 (备份/停止)
  │
  ├─ T1: 启动新版本备份实例
  │      nginx → API:8000 (活跃)
  │               API:8001 (启动中...)
  │
  ├─ T2: 备份实例就绪，开始接收流量
  │      nginx → API:8000 (活跃) ──┐
  │               API:8001 (活跃) ◄─┘ 负载均衡
  │
  ├─ T3: 重启主实例
  │      nginx → API:8000 (重启中)
  │               API:8001 (活跃) ← 所有流量
  │
  ├─ T4: 主实例就绪
  │      nginx → API:8000 (活跃) ──┐
  │               API:8001 (活跃) ◄─┘ 负载均衡
  │
  └─ T5: 完成
         全程无服务中断 ✓
```

### Nginx 故障转移机制

```nginx
upstream api_backend {
    server 127.0.0.1:8000 max_fails=3 fail_timeout=30s;
    server 127.0.0.1:8001 max_fails=3 fail_timeout=30s backup;

    # 自动故障转移
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
}
```

当主实例不可用时，Nginx 自动将请求转发到备份实例。

## 快速部署

### 1. 服务器初始化（首次部署）

```bash
# 上传并执行初始化脚本
scp deploy/scripts/setup.sh root@your-server:/tmp/
ssh root@your-server 'chmod +x /tmp/setup.sh && /tmp/setup.sh'
```

### 2. 部署代码

```bash
# SSH 到服务器
ssh root@your-server

# 切换到应用用户
su - ai-bookkeeping

# 克隆代码
git clone https://github.com/topn2024/ai-bookkeeping.git /home/ai-bookkeeping/app

# 配置环境变量
cp /home/ai-bookkeeping/app/server/.env.example /home/ai-bookkeeping/app/server/.env
vim /home/ai-bookkeeping/app/server/.env

# 安装依赖
source /home/ai-bookkeeping/venv/bin/activate
pip install -r /home/ai-bookkeeping/app/server/requirements.txt

# 退出到 root 用户启动服务
exit

# 启动服务
systemctl enable ai-bookkeeping-api@8000
systemctl enable ai-bookkeeping-admin
systemctl start ai-bookkeeping-api@8000
systemctl start ai-bookkeeping-admin
```

### 3. 后续更新

```bash
# 完整部署（代码 + 数据库迁移）
./deploy/scripts/deploy.sh

# 仅部署代码
./deploy/scripts/deploy.sh --code-only

# 仅数据库迁移
./deploy/scripts/deploy.sh --migrate-only

# 回滚
./deploy/scripts/deploy.sh --rollback

# 查看状态
./deploy/scripts/deploy.sh --status
```

## 目录结构

```
/home/ai-bookkeeping/
├── app/                    # 应用代码
│   ├── server/            # 后端代码
│   │   ├── app/           # 主 API
│   │   ├── admin/         # Admin API
│   │   ├── migrations/    # 数据库迁移
│   │   └── .env           # 环境变量
│   └── admin-web/         # Admin 前端
├── venv/                   # Python 虚拟环境
├── backups/               # 部署备份
└── logs/                  # 应用日志

/var/log/
├── ai-bookkeeping/        # 应用日志（符号链接）
└── nginx/
    ├── ai-bookkeeping-api-access.log
    └── ai-bookkeeping-api-error.log

/etc/
├── systemd/system/
│   ├── ai-bookkeeping-api@.service   # API 服务模板
│   └── ai-bookkeeping-admin.service  # Admin 服务
└── nginx/
    └── sites-available/
        └── ai-bookkeeping.conf       # Nginx 配置
```

## systemd 命令速查

```bash
# 服务管理
systemctl start ai-bookkeeping-api@8000    # 启动
systemctl stop ai-bookkeeping-api@8000     # 停止
systemctl restart ai-bookkeeping-api@8000  # 重启
systemctl reload ai-bookkeeping-api@8000   # 重载（优雅）
systemctl status ai-bookkeeping-api@8000   # 状态

# 开机自启
systemctl enable ai-bookkeeping-api@8000
systemctl disable ai-bookkeeping-api@8000

# 查看日志
journalctl -u ai-bookkeeping-api@8000 -f           # 实时日志
journalctl -u ai-bookkeeping-api@8000 --since today # 今日日志
journalctl -u ai-bookkeeping-api@8000 -n 100       # 最近100行

# 多实例管理
systemctl start ai-bookkeeping-api@8001    # 启动备份实例
systemctl list-units 'ai-bookkeeping-*'    # 列出所有实例
```

## Nginx 命令速查

```bash
# 配置检查
nginx -t

# 重载配置（不中断连接）
nginx -s reload

# 查看连接状态
nginx -s status

# 查看日志
tail -f /var/log/nginx/ai-bookkeeping-api-access.log
tail -f /var/log/nginx/ai-bookkeeping-api-error.log
```

## 健康检查

```bash
# API 健康检查
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8001/health
curl http://127.0.0.1:8002/health

# 通过 Nginx 检查
curl -k https://localhost/health

# 检查响应头
curl -I http://127.0.0.1:8000/health
```

## 故障排查

### 服务无法启动

```bash
# 查看详细错误
journalctl -u ai-bookkeeping-api@8000 -n 50

# 检查端口占用
netstat -tlnp | grep 8000
lsof -i :8000

# 检查权限
ls -la /home/ai-bookkeeping/app/server/
```

### Nginx 502 错误

```bash
# 检查上游服务是否运行
curl http://127.0.0.1:8000/health

# 检查 Nginx 错误日志
tail -f /var/log/nginx/ai-bookkeeping-api-error.log

# 检查 SELinux（如果启用）
setsebool -P httpd_can_network_connect 1
```

### 数据库连接失败

```bash
# 测试数据库连接
psql -h localhost -U ai_bookkeeping -d ai_bookkeeping

# 检查 PostgreSQL 服务
systemctl status postgresql

# 检查环境变量
cat /home/ai-bookkeeping/app/server/.env | grep DATABASE
```

## 监控建议

### 基础监控

```bash
# 安装 htop 查看资源
htop

# 检查磁盘空间
df -h

# 检查内存
free -m

# 检查进程
ps aux | grep uvicorn
```

### 推荐监控工具

- **Prometheus + Grafana**: 指标监控和可视化
- **Loki**: 日志聚合
- **Alertmanager**: 告警管理

## 备份策略

### 自动备份脚本

```bash
#!/bin/bash
# /etc/cron.daily/ai-bookkeeping-backup

BACKUP_DIR="/home/ai-bookkeeping/backups/daily"
DATE=$(date +%Y%m%d)

# 数据库备份
pg_dump -h localhost -U ai_bookkeeping ai_bookkeeping | gzip > "${BACKUP_DIR}/db_${DATE}.sql.gz"

# 保留最近 7 天
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
```

### 恢复数据库

```bash
gunzip -c backup.sql.gz | psql -h localhost -U ai_bookkeeping ai_bookkeeping
```

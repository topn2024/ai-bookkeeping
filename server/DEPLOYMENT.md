# 部署和运行指南

## 数据质量监控功能部署

本文档说明如何部署数据质量监控功能（阶段1）。

### 前置条件

1. Docker 和 Docker Compose 已安装
2. Python 3.11+ 已安装
3. Node.js 16+ 已安装（用于前端构建）

### 1. 环境准备

#### 1.1 创建环境变量文件

在 `server/` 目录下创建 `.env` 文件：

```bash
# Database
POSTGRES_USER=ai_bookkeeping
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=ai_bookkeeping
DATABASE_URL=postgresql+asyncpg://ai_bookkeeping:your_secure_password@localhost:5432/ai_bookkeeping

# Redis
REDIS_PASSWORD=your_redis_password
REDIS_URL=redis://:your_redis_password@localhost:6379/0

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_minio_password

# Celery
CELERY_BROKER_URL=redis://:your_redis_password@localhost:6379/1
CELERY_RESULT_BACKEND=redis://:your_redis_password@localhost:6379/2
CELERY_TIMEZONE=Asia/Shanghai
```

#### 1.2 启动基础设施服务

```bash
cd server
docker compose up -d postgres redis
```

等待服务启动完成：

```bash
docker compose ps
```

确保 postgres 和 redis 状态为 `healthy`。

### 2. 数据库迁移

#### 2.1 安装 Python 依赖

```bash
# 创建虚拟环境
python3 -m venv .venv

# 激活虚拟环境
source .venv/bin/activate  # Linux/macOS
# 或
.venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt
```

#### 2.2 运行数据库迁移

```bash
# 查看当前迁移状态
alembic current

# 查看待执行的迁移
alembic history

# 执行迁移到最新版本
alembic upgrade head

# 验证迁移是否成功
alembic current
```

#### 2.3 验证表结构

使用 Adminer 或 psql 验证：

```bash
# 使用 Docker 容器连接数据库
docker exec -it aibook-postgres psql -U ai_bookkeeping -d ai_bookkeeping

# 查看表结构
\d data_quality_checks

# 查看索引
\di

# 退出
\q
```

或者使用 Adminer Web UI：
- 访问 http://localhost:8080
- 服务器: postgres
- 用户名: ai_bookkeeping
- 密码: your_secure_password
- 数据库: ai_bookkeeping

### 3. 启动 Celery Worker

数据质量监控功能依赖 Celery 后台任务。

#### 3.1 启动 Celery Worker

```bash
# 在 server/ 目录下，确保虚拟环境已激活
cd server
source .venv/bin/activate

# 启动 worker（包含 beat 调度器）
celery -A app.tasks.celery_app worker --beat --loglevel=info

# 或者分别启动 worker 和 beat
# Terminal 1: Worker
celery -A app.tasks.celery_app worker --loglevel=info

# Terminal 2: Beat Scheduler
celery -A app.tasks.celery_app beat --loglevel=info
```

#### 3.2 验证 Celery 任务

```bash
# 测试健康检查任务
celery -A app.tasks.celery_app call app.tasks.health_check

# 手动触发数据质量检查
celery -A app.tasks.celery_app call app.tasks.data_quality_tasks.periodic_data_quality_check
```

### 4. 启动后端 API 服务

```bash
# 在 server/ 目录下
cd server
source .venv/bin/activate

# 启动 FastAPI 服务
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 或者使用生产模式
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

验证 API：
- 访问 http://localhost:8000/docs 查看 API 文档
- 数据质量监控 API 在 `/admin/monitoring/data-quality/` 路径下

### 5. 构建和部署前端

#### 5.1 安装前端依赖

```bash
cd admin-web
npm install
```

#### 5.2 开发模式

```bash
npm run dev
```

访问 http://localhost:5173/admin-web/

#### 5.3 生产构建

```bash
npm run build

# 构建产物在 admin-web/dist/ 目录
```

### 6. 配置管理员权限

数据质量监控页面需要以下权限：

- `monitor:data_quality:view` - 查看数据质量信息
- `monitor:data_quality:manage` - 管理数据质量问题（标记解决/忽略）

#### 6.1 通过管理后台配置权限

1. 登录管理后台
2. 进入"系统设置" -> "管理员"
3. 编辑管理员角色
4. 添加上述权限

#### 6.2 通过数据库直接配置（仅开发环境）

```sql
-- 假设已有管理员角色 ID 为 1
INSERT INTO admin_permissions (name, description, resource, action)
VALUES
  ('monitor:data_quality:view', '查看数据质量监控', 'monitor', 'data_quality:view'),
  ('monitor:data_quality:manage', '管理数据质量问题', 'monitor', 'data_quality:manage');

-- 将权限分配给角色
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM admin_permissions
WHERE name IN ('monitor:data_quality:view', 'monitor:data_quality:manage');
```

### 7. 验证功能

#### 7.1 验证后端 API

```bash
# 获取数据质量概览
curl -X GET "http://localhost:8000/admin/monitoring/data-quality/overview?days=7" \
  -H "Authorization: Bearer YOUR_TOKEN"

# 获取检查列表
curl -X GET "http://localhost:8000/admin/monitoring/data-quality/checks?page=1&page_size=20" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

#### 7.2 验证前端页面

1. 登录管理后台
2. 点击"系统监控" -> "数据质量"
3. 查看数据质量总览
4. 查看问题列表
5. 测试问题详情和处理功能

#### 7.3 验证 Celery 定时任务

查看 Celery 日志，确认定时任务正常执行：

```bash
# 查看 worker 日志
# 应该看到每小时第10分钟执行的数据质量检查任务
# 日志示例：
# [2026-01-11 10:10:00] Task app.tasks.data_quality_tasks.periodic_data_quality_check[...]
```

### 8. 监控和日志

#### 8.1 应用日志

```bash
# 后端日志
tail -f server/logs/app.log

# Celery 日志
# 查看 celery worker 的控制台输出
```

#### 8.2 数据库日志

```bash
# 查看 PostgreSQL 日志
docker logs aibook-postgres -f
```

#### 8.3 Redis 日志

```bash
# 查看 Redis 日志
docker logs aibook-redis -f
```

### 9. 故障排查

#### 9.1 数据库连接失败

```bash
# 检查数据库是否运行
docker ps | grep postgres

# 检查数据库连接
docker exec -it aibook-postgres psql -U ai_bookkeeping -d ai_bookkeeping -c "SELECT 1"

# 查看数据库日志
docker logs aibook-postgres
```

#### 9.2 Celery 任务不执行

```bash
# 检查 Redis 连接
redis-cli -h localhost -p 6379 -a your_redis_password ping

# 检查 Celery 队列
celery -A app.tasks.celery_app inspect active

# 检查定时任务配置
celery -A app.tasks.celery_app inspect scheduled
```

#### 9.3 API 返回 500 错误

```bash
# 查看后端日志
tail -f server/logs/app.log

# 检查数据库表是否存在
docker exec -it aibook-postgres psql -U ai_bookkeeping -d ai_bookkeeping -c "\dt"
```

### 10. 生产部署建议

#### 10.1 使用进程管理器

推荐使用 systemd 或 supervisor 管理服务：

**Celery Worker (systemd)**

创建 `/etc/systemd/system/aibook-celery-worker.service`：

```ini
[Unit]
Description=AI Bookkeeping Celery Worker
After=network.target redis.target postgresql.target

[Service]
Type=forking
User=www-data
Group=www-data
WorkingDirectory=/path/to/ai-bookkeeping/server
Environment="PATH=/path/to/ai-bookkeeping/server/.venv/bin"
ExecStart=/path/to/ai-bookkeeping/server/.venv/bin/celery -A app.tasks.celery_app worker --beat --loglevel=info --logfile=/var/log/aibook/celery-worker.log
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：

```bash
sudo systemctl daemon-reload
sudo systemctl enable aibook-celery-worker
sudo systemctl start aibook-celery-worker
```

**FastAPI (systemd)**

创建 `/etc/systemd/system/aibook-api.service`：

```ini
[Unit]
Description=AI Bookkeeping API
After=network.target postgresql.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/path/to/ai-bookkeeping/server
Environment="PATH=/path/to/ai-bookkeeping/server/.venv/bin"
ExecStart=/path/to/ai-bookkeeping/server/.venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
Restart=always

[Install]
WantedBy=multi-user.target
```

#### 10.2 配置 Nginx 反向代理

```nginx
# /etc/nginx/sites-available/aibook-admin

upstream aibook_api {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name admin.example.com;

    # 前端静态文件
    location /admin-web/ {
        alias /path/to/ai-bookkeeping/admin-web/dist/;
        try_files $uri $uri/ /admin-web/index.html;
    }

    # API 代理
    location /api/ {
        proxy_pass http://aibook_api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /admin/ {
        proxy_pass http://aibook_api/admin/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### 10.3 数据库备份

```bash
# 创建备份脚本
cat > /opt/scripts/backup-aibook-db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR=/var/backups/aibook
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

docker exec aibook-postgres pg_dump -U ai_bookkeeping ai_bookkeeping | \
  gzip > $BACKUP_DIR/aibook_$DATE.sql.gz

# 保留最近30天的备份
find $BACKUP_DIR -name "aibook_*.sql.gz" -mtime +30 -delete
EOF

chmod +x /opt/scripts/backup-aibook-db.sh

# 配置 cron 每天凌晨3点备份
echo "0 3 * * * /opt/scripts/backup-aibook-db.sh" | crontab -
```

### 11. 后续阶段

完成阶段1后，继续实施：

- **阶段2**: 千人千面内容监控（2周）
- **阶段3**: 数据分析功能监控（1.5周）
- **阶段4**: AI成本监控（1.5周）

每个阶段的详细任务请参考 `openspec/changes/enhance-admin-monitoring/tasks.md`。

## 相关文档

- [OpenSpec 提案](../openspec/changes/enhance-admin-monitoring/proposal.md)
- [技术设计](../openspec/changes/enhance-admin-monitoring/design.md)
- [任务清单](../openspec/changes/enhance-admin-monitoring/tasks.md)
- [数据质量监控规范](../openspec/changes/enhance-admin-monitoring/specs/data-quality-monitoring/spec.md)

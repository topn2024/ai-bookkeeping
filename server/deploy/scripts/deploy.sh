#!/bin/bash
# ==============================================================================
# AI Bookkeeping - 零停机部署脚本
# ==============================================================================
# 使用方式:
#   ./deploy.sh                 # 完整部署（代码 + 数据库迁移）
#   ./deploy.sh --code-only     # 仅部署代码，跳过迁移
#   ./deploy.sh --migrate-only  # 仅执行数据库迁移
#   ./deploy.sh --rollback      # 回滚到上一版本
# ==============================================================================

set -e  # 遇到错误立即退出

# ============ 配置 ============
APP_NAME="ai-bookkeeping"
APP_USER="ai-bookkeeping"
APP_DIR="/home/ai-bookkeeping/app"
VENV_DIR="/home/ai-bookkeeping/venv"
BACKUP_DIR="/home/ai-bookkeeping/backups"
LOG_DIR="/var/log/ai-bookkeeping"
GIT_REPO="https://github.com/topn2024/ai-bookkeeping.git"
GIT_BRANCH="master"

# 服务端口
API_PORT_PRIMARY=8000
API_PORT_BACKUP=8001
ADMIN_PORT=8002

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ 辅助函数 ============

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 检查服务健康状态
check_health() {
    local port=$1
    local max_attempts=${2:-30}
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -sf "http://127.0.0.1:${port}/health" > /dev/null 2>&1; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

# 等待服务停止
wait_service_stop() {
    local service=$1
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if ! systemctl is-active --quiet "$service"; then
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    return 1
}

# 创建备份
create_backup() {
    log_step "创建备份..."

    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_path="${BACKUP_DIR}/${timestamp}"

    mkdir -p "$backup_path"

    # 备份代码
    if [ -d "${APP_DIR}/server" ]; then
        cp -r "${APP_DIR}/server" "${backup_path}/server"
        log_info "代码备份完成: ${backup_path}/server"
    fi

    # 记录当前 Git commit
    if [ -d "${APP_DIR}/.git" ]; then
        cd "$APP_DIR"
        sudo -u "$APP_USER" git rev-parse HEAD > "${backup_path}/git_commit.txt"
        log_info "Git commit 记录: $(cat ${backup_path}/git_commit.txt)"
    fi

    # 备份数据库（可选，根据需要启用）
    # pg_dump -h localhost -U ai_bookkeeping ai_bookkeeping > "${backup_path}/database.sql"
    # log_info "数据库备份完成"

    # 保留最近 10 个备份
    cd "$BACKUP_DIR"
    ls -t | tail -n +11 | xargs -r rm -rf

    echo "$backup_path"
}

# ============ 部署步骤 ============

# 步骤 1: 拉取最新代码
pull_code() {
    log_step "拉取最新代码..."

    cd "$APP_DIR"

    # 保存当前 commit（使用 ai-bookkeeping 用户执行 git 操作）
    local old_commit=$(sudo -u "$APP_USER" git rev-parse HEAD 2>/dev/null || echo "none")

    # 拉取代码（使用 ai-bookkeeping 用户，确保文件权限正确）
    sudo -u "$APP_USER" git fetch origin "$GIT_BRANCH"
    sudo -u "$APP_USER" git reset --hard "origin/$GIT_BRANCH"

    local new_commit=$(sudo -u "$APP_USER" git rev-parse HEAD)

    if [ "$old_commit" = "$new_commit" ]; then
        log_info "代码已是最新版本: $new_commit"
    else
        log_info "代码已更新: $old_commit -> $new_commit"

        # 显示变更日志
        sudo -u "$APP_USER" git log --oneline "${old_commit}..${new_commit}" 2>/dev/null || true
    fi
}

# 步骤 2: 安装依赖
install_dependencies() {
    log_step "安装 Python 依赖..."

    cd "${APP_DIR}/server"

    # 激活虚拟环境并安装依赖
    source "${VENV_DIR}/bin/activate"
    pip install -r requirements.txt --quiet

    log_info "依赖安装完成"
}

# 步骤 3: 执行数据库迁移
run_migrations() {
    log_step "执行数据库迁移..."

    cd "${APP_DIR}/server"
    source "${VENV_DIR}/bin/activate"

    # 检查是否配置了 Alembic
    if [ ! -f "alembic.ini" ]; then
        log_warn "未配置 Alembic，跳过自动迁移"
        log_warn "请手动检查 migrations/ 目录中的 SQL 文件"
        return 0
    fi

    # 检查当前迁移状态
    log_info "检查迁移状态..."
    local current_rev=$(alembic current 2>/dev/null | head -1 | cut -d' ' -f1)
    local head_rev=$(alembic heads 2>/dev/null | head -1 | cut -d' ' -f1)

    log_info "当前版本: ${current_rev:-未初始化}"
    log_info "目标版本: ${head_rev:-未知}"

    # 如果已是最新，跳过
    if [ "$current_rev" = "$head_rev" ] && [ -n "$current_rev" ]; then
        log_info "数据库已是最新版本，跳过迁移"
        return 0
    fi

    # 创建数据库备份
    log_info "创建数据库备份..."
    if command -v pg_dump &> /dev/null; then
        local db_backup="${BACKUP_DIR}/db/pre_migrate_$(date '+%Y%m%d_%H%M%S').sql"
        mkdir -p "${BACKUP_DIR}/db"

        # 从环境变量或配置获取数据库连接信息
        if [ -n "$DATABASE_URL" ]; then
            # 使用 Python 脚本备份
            python scripts/migrate.py backup --tag "pre_deploy" 2>/dev/null || {
                log_warn "数据库备份失败，继续执行迁移..."
            }
        else
            log_warn "未设置 DATABASE_URL，跳过数据库备份"
        fi
    else
        log_warn "pg_dump 未安装，跳过数据库备份"
    fi

    # 执行迁移
    log_info "执行数据库迁移..."
    if alembic upgrade head; then
        log_info "Alembic 迁移完成"

        # 验证迁移结果
        local new_rev=$(alembic current 2>/dev/null | head -1 | cut -d' ' -f1)
        log_info "迁移后版本: $new_rev"
    else
        log_error "数据库迁移失败!"
        log_error "请检查错误信息并手动修复"
        log_error "回滚命令: alembic downgrade -1"
        log_error "或恢复备份: python scripts/migrate.py restore"
        return 1
    fi
}

# 步骤 4: 零停机重启服务（滚动更新）
rolling_restart() {
    log_step "执行滚动重启..."

    # === 阶段 1: 启动备份实例 ===
    log_info "启动备份实例 (端口 $API_PORT_BACKUP)..."
    systemctl start "ai-bookkeeping-api@${API_PORT_BACKUP}" || true

    # 等待备份实例健康
    if check_health $API_PORT_BACKUP 30; then
        log_info "备份实例已就绪"
    else
        log_error "备份实例启动失败"
        systemctl status "ai-bookkeeping-api@${API_PORT_BACKUP}" || true
        return 1
    fi

    # === 阶段 2: 更新 Nginx 配置，将流量切换到备份实例 ===
    log_info "切换流量到备份实例..."

    # 临时修改 upstream 配置
    # 方法1: 使用 nginx upstream 动态管理（需要 nginx-plus 或 lua 模块）
    # 方法2: 简单方式 - 依赖 nginx 的 backup 和 fail_timeout 机制

    # === 阶段 3: 重启主实例 ===
    log_info "重启主实例 (端口 $API_PORT_PRIMARY)..."
    systemctl restart "ai-bookkeeping-api@${API_PORT_PRIMARY}"

    # 等待主实例健康
    if check_health $API_PORT_PRIMARY 30; then
        log_info "主实例已就绪"
    else
        log_error "主实例重启失败，保持备份实例运行"
        return 1
    fi

    # === 阶段 4: 停止备份实例（可选，保留作为热备） ===
    # log_info "停止备份实例..."
    # systemctl stop "ai-bookkeeping-api@${API_PORT_BACKUP}"

    # 或者保持备份实例运行作为负载均衡
    log_info "保持备份实例运行作为负载均衡"

    # === 阶段 5: 重启 Admin API ===
    log_info "重启 Admin API..."
    systemctl restart ai-bookkeeping-admin

    if check_health $ADMIN_PORT 30; then
        log_info "Admin API 已就绪"
    else
        log_warn "Admin API 重启可能有问题，请检查"
    fi

    log_info "滚动重启完成"
}

# 简单重启（适用于单实例）
simple_restart() {
    log_step "重启服务..."

    # 使用 systemd 的优雅停止
    systemctl restart "ai-bookkeeping-api@${API_PORT_PRIMARY}"

    if check_health $API_PORT_PRIMARY 30; then
        log_info "API 服务已就绪"
    else
        log_error "API 服务启动失败"
        return 1
    fi

    systemctl restart ai-bookkeeping-admin

    if check_health $ADMIN_PORT 30; then
        log_info "Admin 服务已就绪"
    else
        log_warn "Admin 服务可能有问题"
    fi
}

# 数据库迁移回滚
db_rollback() {
    log_step "执行数据库迁移回滚..."

    cd "${APP_DIR}/server"
    source "${VENV_DIR}/bin/activate"

    if [ ! -f "alembic.ini" ]; then
        log_error "未配置 Alembic，无法回滚"
        return 1
    fi

    # 显示当前状态
    log_info "当前迁移状态:"
    alembic current

    # 创建备份
    log_info "创建回滚前备份..."
    python scripts/migrate.py backup --tag "pre_rollback" 2>/dev/null || {
        log_warn "备份失败，是否继续？(y/n)"
        read -r confirm
        if [ "$confirm" != "y" ]; then
            log_info "回滚已取消"
            return 0
        fi
    }

    # 执行回滚
    log_info "回滚到上一版本..."
    if alembic downgrade -1; then
        log_info "数据库回滚成功"

        # 显示回滚后状态
        log_info "回滚后迁移状态:"
        alembic current
    else
        log_error "数据库回滚失败!"
        log_error "可以使用数据库备份恢复: python scripts/migrate.py restore"
        return 1
    fi
}

# 回滚到上一版本
rollback() {
    log_step "执行回滚..."

    # 获取最近的备份
    local latest_backup=$(ls -t "$BACKUP_DIR" | head -1)

    if [ -z "$latest_backup" ]; then
        log_error "没有找到可用的备份"
        return 1
    fi

    local backup_path="${BACKUP_DIR}/${latest_backup}"
    log_info "使用备份: $backup_path"

    # 恢复代码
    if [ -d "${backup_path}/server" ]; then
        rm -rf "${APP_DIR}/server"
        cp -r "${backup_path}/server" "${APP_DIR}/server"
        log_info "代码已恢复"
    fi

    # 如果有 Git commit 记录，回滚到该版本（使用 ai-bookkeeping 用户）
    if [ -f "${backup_path}/git_commit.txt" ]; then
        local commit=$(cat "${backup_path}/git_commit.txt")
        cd "$APP_DIR"
        sudo -u "$APP_USER" git reset --hard "$commit"
        log_info "Git 已回滚到: $commit"
    fi

    # 重启服务
    simple_restart

    log_info "回滚完成"
}

# 部署前检查
pre_deploy_check() {
    log_step "部署前检查..."

    # 检查用户权限
    if [ "$(id -u)" != "0" ] && [ "$(whoami)" != "$APP_USER" ]; then
        log_error "请使用 root 或 $APP_USER 用户执行"
        exit 1
    fi

    # 检查目录
    if [ ! -d "$APP_DIR" ]; then
        log_error "应用目录不存在: $APP_DIR"
        exit 1
    fi

    # 检查 systemd 服务
    if ! systemctl list-unit-files | grep -q "ai-bookkeeping-api@"; then
        log_warn "systemd 服务未安装，请先安装服务文件"
    fi

    # 检查 nginx
    if ! nginx -t 2>/dev/null; then
        log_error "Nginx 配置有误"
        exit 1
    fi

    log_info "检查通过"
}

# 显示部署状态
show_status() {
    echo ""
    echo "============ 服务状态 ============"
    echo ""

    echo "API 服务 (端口 $API_PORT_PRIMARY):"
    systemctl status "ai-bookkeeping-api@${API_PORT_PRIMARY}" --no-pager -l 2>/dev/null || echo "  未运行"
    echo ""

    echo "API 备份 (端口 $API_PORT_BACKUP):"
    systemctl status "ai-bookkeeping-api@${API_PORT_BACKUP}" --no-pager -l 2>/dev/null || echo "  未运行"
    echo ""

    echo "Admin 服务 (端口 $ADMIN_PORT):"
    systemctl status ai-bookkeeping-admin --no-pager -l 2>/dev/null || echo "  未运行"
    echo ""

    echo "============ 健康检查 ============"
    echo ""

    for port in $API_PORT_PRIMARY $API_PORT_BACKUP $ADMIN_PORT; do
        if curl -sf "http://127.0.0.1:${port}/health" > /dev/null 2>&1; then
            echo -e "  端口 $port: ${GREEN}健康${NC}"
        else
            echo -e "  端口 $port: ${RED}不可用${NC}"
        fi
    done
    echo ""
}

# ============ 主函数 ============

main() {
    local mode="full"

    # 解析参数
    case "${1:-}" in
        --code-only)
            mode="code"
            ;;
        --migrate-only)
            mode="migrate"
            ;;
        --rollback)
            mode="rollback"
            ;;
        --status)
            show_status
            exit 0
            ;;
        --db-rollback)
            mode="db-rollback"
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  (无参数)        完整部署（代码 + 迁移 + 重启）"
            echo "  --code-only     仅部署代码，跳过迁移"
            echo "  --migrate-only  仅执行数据库迁移"
            echo "  --rollback      回滚到上一版本（代码 + 服务）"
            echo "  --db-rollback   回滚数据库到上一迁移版本"
            echo "  --status        显示服务状态"
            echo "  --help          显示帮助"
            exit 0
            ;;
    esac

    echo ""
    echo "================================================"
    echo "  AI Bookkeeping 部署脚本"
    echo "  模式: $mode"
    echo "  时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "================================================"
    echo ""

    # 部署前检查
    pre_deploy_check

    # 根据模式执行
    case "$mode" in
        full)
            create_backup
            pull_code
            install_dependencies
            run_migrations
            rolling_restart
            ;;
        code)
            create_backup
            pull_code
            install_dependencies
            rolling_restart
            ;;
        migrate)
            create_backup
            run_migrations
            ;;
        rollback)
            rollback
            ;;
        db-rollback)
            db_rollback
            ;;
    esac

    # 显示最终状态
    show_status

    echo ""
    log_info "部署完成!"
    echo ""
}

# 执行主函数
main "$@"

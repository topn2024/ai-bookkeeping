#!/bin/bash

# AI记账应用一键式发布脚本
# 功能：
# 1. 更新版本号（pubspec.yaml和build_info.dart）
# 2. 编译release APK
# 3. 上传到两个服务器
# 4. 在两个服务器数据库创建版本记录
# 5. 提交代码到GitHub

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 服务器配置
SERVER1_IP="39.105.12.124"
SERVER1_PASSWORD=""  # 在运行时输入
SERVER2_IP="160.202.238.29"
SERVER2_PASSWORD="65QLkJ0CogNI"

# 路径配置
APP_DIR="/Users/beihua/code/baiji/ai-bookkeeping/app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的工具
check_requirements() {
    log_info "检查必要工具..."

    local tools=("flutter" "sshpass" "git" "python3")
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool 未安装，请先安装"
            exit 1
        fi
    done

    log_info "所有必要工具已安装"
}

# 获取当前版本号
get_current_version() {
    cd "$APP_DIR"
    local version_line=$(grep "^version:" pubspec.yaml)
    echo "$version_line" | sed 's/version: //'
}

# 解析版本号
parse_version() {
    local version=$1
    local version_name=$(echo "$version" | cut -d'+' -f1)
    local build_number=$(echo "$version" | cut -d'+' -f2)
    echo "$version_name $build_number"
}

# 递增版本号
increment_version() {
    local current_version=$1
    local increment_type=$2  # major, minor, patch, build

    read version_name build_number <<< $(parse_version "$current_version")

    IFS='.' read -ra VERSION_PARTS <<< "$version_name"
    local major=${VERSION_PARTS[0]}
    local minor=${VERSION_PARTS[1]}
    local patch=${VERSION_PARTS[2]}

    case $increment_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            build_number=$((build_number + 1))
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            build_number=$((build_number + 1))
            ;;
        patch)
            patch=$((patch + 1))
            build_number=$((build_number + 1))
            ;;
        build)
            build_number=$((build_number + 1))
            ;;
        *)
            log_error "未知的版本递增类型: $increment_type"
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}+${build_number}"
}

# 更新pubspec.yaml
update_pubspec() {
    local new_version=$1
    log_info "更新 pubspec.yaml 版本为 $new_version"

    cd "$APP_DIR"
    sed -i.bak "s/^version: .*/version: $new_version/" pubspec.yaml
    rm pubspec.yaml.bak
}

# 更新build_info.dart
update_build_info() {
    local new_version=$1
    read version_name build_number <<< $(parse_version "$new_version")

    log_info "更新 build_info.dart 版本为 $new_version"

    local build_time=$(date -u +"%Y-%m-%dT%H:%M:%S.000000")
    local build_time_formatted=$(date +"%Y-%m-%d %H:%M:%S")

    cat > "$APP_DIR/lib/core/build_info.dart" <<EOF
/// 自动生成的构建信息 - 请勿手动修改
/// 生成时间: $build_time_formatted

class BuildInfo {
  /// 构建时间 (ISO 8601)
  static const String buildTime = '$build_time';

  /// 构建时间 (格式化显示)
  static const String buildTimeFormatted = '$build_time_formatted';

  /// 版本号
  static const String version = '$version_name';

  /// 构建号
  static const int buildNumber = $build_number;

  /// 完整版本
  static const String fullVersion = '$new_version';

  /// 构建类型 (Debug/Release)
  static const String buildType = 'Release';

  /// 带类型的完整版本号
  static const String displayVersion = '$version_name';
}
EOF
}

# 编译APK
build_apk() {
    log_info "开始编译 release APK..."

    cd "$APP_DIR"
    flutter clean
    flutter build apk --release --no-tree-shake-icons

    if [ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        log_error "APK编译失败"
        exit 1
    fi

    log_info "APK编译成功"
}

# 计算MD5
calculate_md5() {
    local file_path=$1
    md5 -q "$file_path"
}

# 获取文件大小
get_file_size() {
    local file_path=$1
    stat -f%z "$file_path"
}

# 上传APK到服务器
upload_to_server() {
    local server_ip=$1
    local server_password=$2
    local apk_path=$3
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local remote_filename="ai-bookkeeping-${timestamp}.apk"

    log_info "上传APK到服务器 $server_ip..."

    sshpass -p "$server_password" scp "$apk_path" "root@${server_ip}:/tmp/ai-bookkeeping-release.apk"

    sshpass -p "$server_password" ssh "root@${server_ip}" "
        mkdir -p /usr/share/nginx/html/downloads
        mv /tmp/ai-bookkeeping-release.apk /usr/share/nginx/html/downloads/${remote_filename}
        ln -sf ${remote_filename} /usr/share/nginx/html/downloads/ai-bookkeeping-latest.apk
        ls -lh /usr/share/nginx/html/downloads/${remote_filename}
    "

    echo "$remote_filename"
}

# 在数据库中创建版本记录
create_version_record() {
    local server_ip=$1
    local server_password=$2
    local version_name=$3
    local build_number=$4
    local file_url=$5
    local file_size=$6
    local file_md5=$7
    local release_notes=$8

    log_info "在服务器 $server_ip 数据库中创建版本记录..."

    # 转义单引号
    release_notes=$(echo "$release_notes" | sed "s/'/''/g")

    sshpass -p "$server_password" ssh "root@${server_ip}" "sudo -u postgres psql ai_bookkeeping -c \"
INSERT INTO app_versions (
    id, version_name, version_code, platform,
    file_url, file_size, file_md5,
    release_notes, is_force_update, status,
    published_at, rollout_percentage, created_by, created_at, updated_at
) VALUES (
    gen_random_uuid(),
    '$version_name',
    $build_number,
    'android',
    '$file_url',
    $file_size,
    '$file_md5',
    '$release_notes',
    false,
    1,
    NOW(),
    100,
    'release-script',
    NOW(),
    NOW()
) RETURNING id, version_name, version_code;
\""
}

# 提交到Git
commit_to_git() {
    local version=$1
    local release_notes=$2

    log_info "提交代码到Git..."

    cd "$PROJECT_ROOT"

    git add app/pubspec.yaml app/lib/core/build_info.dart

    git commit -m "chore: 发布版本 $version

$release_notes

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

    git push origin master

    log_info "代码已提交到GitHub"
}

# 主流程
main() {
    log_info "========== AI记账应用一键式发布 =========="

    # 检查环境
    check_requirements

    # 获取当前版本
    local current_version=$(get_current_version)
    log_info "当前版本: $current_version"

    # 询问版本递增方式
    echo ""
    echo "请选择版本递增方式:"
    echo "1) Major (大版本，如 2.0.0 -> 3.0.0)"
    echo "2) Minor (小版本，如 2.0.0 -> 2.1.0)"
    echo "3) Patch (补丁版本，如 2.0.0 -> 2.0.1) [推荐]"
    echo "4) Build (仅构建号，如 2.0.0+54 -> 2.0.0+55)"
    echo "5) 自定义版本号"
    read -p "请输入选项 (1-5): " version_option

    case $version_option in
        1) new_version=$(increment_version "$current_version" "major") ;;
        2) new_version=$(increment_version "$current_version" "minor") ;;
        3) new_version=$(increment_version "$current_version" "patch") ;;
        4) new_version=$(increment_version "$current_version" "build") ;;
        5)
            read -p "请输入新版本号 (格式: x.y.z+n): " new_version
            ;;
        *)
            log_error "无效的选项"
            exit 1
            ;;
    esac

    log_info "新版本: $new_version"

    # 获取更新说明
    echo ""
    echo "请输入本次更新说明 (多行输入，输入END结束):"
    release_notes=""
    while IFS= read -r line; do
        if [ "$line" = "END" ]; then
            break
        fi
        release_notes="${release_notes}${line}\n"
    done

    if [ -z "$release_notes" ]; then
        release_notes="版本更新"
    fi

    # 确认发布
    echo ""
    log_warn "即将发布版本 $new_version，更新说明:"
    echo -e "$release_notes"
    read -p "确认发布? (y/N): " confirm

    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消发布"
        exit 0
    fi

    # 1. 更新版本号
    update_pubspec "$new_version"
    update_build_info "$new_version"

    # 2. 编译APK
    build_apk

    local apk_path="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
    local file_md5=$(calculate_md5 "$apk_path")
    local file_size=$(get_file_size "$apk_path")

    log_info "APK MD5: $file_md5"
    log_info "APK 大小: $(($file_size / 1024 / 1024)) MB"

    # 3. 上传到服务器1
    read version_name build_number <<< $(parse_version "$new_version")
    local filename1=$(upload_to_server "$SERVER1_IP" "" "$apk_path")
    local file_url1="http://${SERVER1_IP}/downloads/${filename1}"

    # 4. 上传到服务器2
    local filename2=$(upload_to_server "$SERVER2_IP" "$SERVER2_PASSWORD" "$apk_path")
    local file_url2="http://${SERVER2_IP}/downloads/${filename2}"

    # 5. 在两个服务器数据库创建版本记录
    create_version_record "$SERVER1_IP" "" "$version_name" "$build_number" "$file_url1" "$file_size" "$file_md5" "$release_notes"
    create_version_record "$SERVER2_IP" "$SERVER2_PASSWORD" "$version_name" "$build_number" "$file_url2" "$file_size" "$file_md5" "$release_notes"

    # 6. 提交到Git
    commit_to_git "$new_version" "$release_notes"

    log_info ""
    log_info "========== 发布成功 =========="
    log_info "版本: $new_version"
    log_info "下载地址1: $file_url1"
    log_info "下载地址2: $file_url2"
    log_info "MD5: $file_md5"
    log_info "============================="
}

# 运行主流程
main "$@"

#!/bin/bash

# Android 开发环境检查脚本
# 用于验证所有必需的开发工具是否正确安装和配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查结果统计
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

echo "======================================"
echo "  Android 开发环境检查工具"
echo "======================================"
echo ""

# 检查函数
check_command() {
    local cmd=$1
    local name=$2
    local required=$3  # true/false

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name 已安装"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))

        # 显示版本信息
        case $cmd in
            java)
                java -version 2>&1 | head -n 1 | sed 's/^/  /'
                ;;
            flutter)
                flutter --version | head -n 1 | sed 's/^/  /'
                ;;
            adb)
                adb --version 2>&1 | head -n 1 | sed 's/^/  /'
                ;;
            *)
                $cmd --version 2>&1 | head -n 1 | sed 's/^/  /' || echo "  (已安装)"
                ;;
        esac
        return 0
    else
        if [ "$required" = true ]; then
            echo -e "${RED}✗${NC} $name ${RED}未安装${NC} (必需)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${YELLOW}○${NC} $name 未安装 (可选)"
        fi
        return 1
    fi
}

# 检查环境变量
check_env_var() {
    local var_name=$1
    local description=$2
    local required=$3

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ -n "${!var_name}" ]; then
        echo -e "${GREEN}✓${NC} $description"
        echo "  $var_name=${!var_name}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$required" = true ]; then
            echo -e "${RED}✗${NC} $description ${RED}未设置${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${YELLOW}○${NC} $description 未设置 (可选)"
        fi
        return 1
    fi
}

# 检查文件或目录
check_path() {
    local path=$1
    local description=$2
    local required=$3

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if [ -e "$path" ]; then
        echo -e "${GREEN}✓${NC} $description"
        echo "  路径: $path"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [ "$required" = true ]; then
            echo -e "${RED}✗${NC} $description ${RED}不存在${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${YELLOW}○${NC} $description 不存在 (可选)"
        fi
        return 1
    fi
}

echo "1️⃣  检查 Java 环境"
echo "-------------------"
check_command java "Java JDK" true
check_command javac "Java 编译器" true
check_env_var JAVA_HOME "JAVA_HOME 环境变量" true
echo ""

echo "2️⃣  检查 Android SDK"
echo "-------------------"
check_env_var ANDROID_HOME "ANDROID_HOME 环境变量" true
if [ -n "$ANDROID_HOME" ]; then
    check_path "$ANDROID_HOME" "Android SDK 目录" true
    check_path "$ANDROID_HOME/platform-tools" "Platform Tools" true
    check_path "$ANDROID_HOME/platforms/android-35" "Android API 35" false
    check_path "$ANDROID_HOME/platforms/android-36" "Android API 36" false
    check_path "$ANDROID_HOME/build-tools" "Build Tools" true
fi
check_command adb "ADB 工具" true
echo ""

echo "3️⃣  检查 Flutter 环境"
echo "-------------------"
check_command flutter "Flutter SDK" true
check_path "/Users/beihua/tools/flutter" "Flutter 安装目录" true
if command -v flutter &> /dev/null; then
    echo "运行 flutter doctor..."
    echo ""
    flutter doctor
    echo ""
fi
echo ""

echo "4️⃣  检查项目配置"
echo "-------------------"
check_path "/Users/beihua/code/baiji/ai-bookkeeping/app/android" "Android 项目目录" true
check_path "/Users/beihua/code/baiji/ai-bookkeeping/app/android/local.properties" "local.properties" true
check_path "/Users/beihua/code/baiji/ai-bookkeeping/app/android/keystore" "签名密钥目录" false

if [ -f "/Users/beihua/code/baiji/ai-bookkeeping/app/android/keystore/release.keystore" ]; then
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -e "${GREEN}✓${NC} Release 签名密钥已生成"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))

    if [ -f "/Users/beihua/code/baiji/ai-bookkeeping/app/android/key.properties" ]; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        echo -e "${GREEN}✓${NC} 签名配置文件已创建"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        echo -e "${YELLOW}○${NC} 签名配置文件未创建"
        echo "  运行: cp app/android/key.properties.example app/android/key.properties"
    fi
else
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -e "${YELLOW}○${NC} Release 签名密钥未生成 (可选)"
    echo "  运行: ./scripts/generate_keystore.sh"
fi
echo ""

echo "5️⃣  检查开发工具"
echo "-------------------"
check_command git "Git" true
check_command code "VS Code" false
check_command studio "Android Studio" false
echo ""

echo "======================================"
echo "  检查结果汇总"
echo "======================================"
echo ""
echo "总共检查项: $TOTAL_CHECKS"
echo -e "${GREEN}通过: $PASSED_CHECKS${NC}"
echo -e "${RED}失败: $FAILED_CHECKS${NC}"
echo ""

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${GREEN}🎉 恭喜！所有必需的环境配置都已完成！${NC}"
    echo ""
    echo "你现在可以："
    echo "  1. 运行应用: cd app && flutter run"
    echo "  2. 构建 APK: cd app && flutter build apk --debug"
    echo "  3. 查看设备: flutter devices"
    echo ""
else
    echo -e "${YELLOW}⚠️  还有 $FAILED_CHECKS 项配置需要完成${NC}"
    echo ""
    echo "请查看上面标记为 ✗ 的项目，并按照提示进行配置。"
    echo ""
    echo "详细配置指南："
    echo "  - Android开发快速开始.md"
    echo "  - Android开发环境配置指南.md"
    echo ""
fi

# 检查 Flutter 项目依赖
if [ -f "/Users/beihua/code/baiji/ai-bookkeeping/app/pubspec.yaml" ]; then
    echo "======================================"
    echo "  Flutter 项目检查"
    echo "======================================"
    echo ""

    cd /Users/beihua/code/baiji/ai-bookkeeping/app

    if [ -d "build" ]; then
        echo -e "${GREEN}✓${NC} 项目已构建过"
    else
        echo -e "${YELLOW}○${NC} 项目尚未构建"
        echo "  建议运行: flutter pub get && flutter build apk --debug"
    fi

    if [ -d ".dart_tool" ]; then
        echo -e "${GREEN}✓${NC} Dart 工具已初始化"
    else
        echo -e "${YELLOW}○${NC} Dart 工具未初始化"
        echo "  运行: flutter pub get"
    fi

    echo ""
fi

echo "======================================"
echo ""

exit 0

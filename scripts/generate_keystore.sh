#!/bin/bash

# Android 签名密钥生成脚本
# 用于为 AI 智能记账应用生成 Release 签名密钥

set -e

echo "======================================"
echo "  Android 签名密钥生成工具"
echo "======================================"
echo ""

# 检查 keytool 是否可用
if ! command -v keytool &> /dev/null; then
    echo "❌ 错误: 未找到 keytool 命令"
    echo "请先安装 Java JDK"
    exit 1
fi

# 定义变量
KEYSTORE_DIR="app/android/keystore"
KEYSTORE_FILE="$KEYSTORE_DIR/release.keystore"
KEY_ALIAS="ai-bookkeeping-release"
KEY_PROPERTIES="app/android/key.properties"

# 检查是否已存在密钥文件
if [ -f "$KEYSTORE_FILE" ]; then
    echo "⚠️  警告: 密钥文件已存在: $KEYSTORE_FILE"
    read -p "是否覆盖现有密钥? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "已取消操作"
        exit 0
    fi
    rm -f "$KEYSTORE_FILE"
fi

# 确保目录存在
mkdir -p "$KEYSTORE_DIR"

echo ""
echo "请输入密钥信息（所有信息都会保存在密钥文件中）："
echo ""

# 读取密码
read -s -p "密钥库密码（至少6位）: " STORE_PASSWORD
echo ""
read -s -p "确认密钥库密码: " STORE_PASSWORD_CONFIRM
echo ""

if [ "$STORE_PASSWORD" != "$STORE_PASSWORD_CONFIRM" ]; then
    echo "❌ 错误: 两次输入的密钥库密码不一致"
    exit 1
fi

read -s -p "密钥密码（至少6位，可与密钥库密码相同）: " KEY_PASSWORD
echo ""
read -s -p "确认密钥密码: " KEY_PASSWORD_CONFIRM
echo ""

if [ "$KEY_PASSWORD" != "$KEY_PASSWORD_CONFIRM" ]; then
    echo "❌ 错误: 两次输入的密钥密码不一致"
    exit 1
fi

echo ""
echo "请输入证书信息（可选，直接回车跳过）："
read -p "您的姓名 [AI Bookkeeping Team]: " CN
CN=${CN:-"AI Bookkeeping Team"}

read -p "组织单位 [Development]: " OU
OU=${OU:-"Development"}

read -p "组织名称 [AI Bookkeeping]: " O
O=${O:-"AI Bookkeeping"}

read -p "城市 [Beijing]: " L
L=${L:-"Beijing"}

read -p "省份 [Beijing]: " ST
ST=${ST:-"Beijing"}

read -p "国家代码 [CN]: " C
C=${C:-"CN"}

echo ""
echo "开始生成签名密钥..."
echo ""

# 生成密钥
keytool -genkey -v \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$STORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -dname "CN=$CN, OU=$OU, O=$O, L=$L, ST=$ST, C=$C"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 密钥生成成功!"
    echo ""
    echo "密钥信息："
    echo "  文件位置: $KEYSTORE_FILE"
    echo "  密钥别名: $KEY_ALIAS"
    echo "  有效期: 10000 天（约27年）"
    echo ""

    # 创建 key.properties 文件
    if [ -f "$KEY_PROPERTIES" ]; then
        echo "⚠️  key.properties 文件已存在"
        read -p "是否覆盖? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            echo "跳过 key.properties 文件创建"
        else
            create_key_properties=true
        fi
    else
        create_key_properties=true
    fi

    if [ "$create_key_properties" = true ]; then
        cat > "$KEY_PROPERTIES" << EOF
# Android 签名密钥配置
# ⚠️ 此文件包含敏感信息，不要提交到版本控制系统！

storeFile=keystore/release.keystore
storePassword=$STORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASSWORD
EOF
        echo "✅ 已创建 key.properties 配置文件"
    fi

    echo ""
    echo "⚠️  重要提示:"
    echo "1. 请妥善保管密钥文件和密码"
    echo "2. 建议将密钥文件备份到安全位置"
    echo "3. 密钥文件已自动添加到 .gitignore，不会提交到仓库"
    echo "4. key.properties 文件包含密码信息，请勿分享或提交"
    echo ""

    # 查看密钥信息
    read -p "是否查看密钥详细信息? (yes/no): " show_info
    if [ "$show_info" = "yes" ]; then
        echo ""
        keytool -list -v -keystore "$KEYSTORE_FILE" -storepass "$STORE_PASSWORD"
    fi

    echo ""
    echo "======================================"
    echo "  配置完成！现在可以构建 Release 版本了"
    echo "======================================"
    echo ""
    echo "构建 Release APK:"
    echo "  cd app && flutter build apk --release"
    echo ""
    echo "构建 App Bundle:"
    echo "  cd app && flutter build appbundle --release"
    echo ""
else
    echo "❌ 密钥生成失败"
    exit 1
fi

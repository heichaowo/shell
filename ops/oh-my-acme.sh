#!/bin/bash

# 确保域名被传递
if [ -z "$1" ]; then
    echo "请提供域名。用法: $0 example.com"
    exit 1
fi

DOMAIN=$1
WEBROOT="/var/www/html"
KEY_DIR="/etc/ssl/$DOMAIN"
ACME_PATH="$HOME/.acme.sh"

# 显示选项菜单
echo "选择要使用的CA (证书颁发机构):"
echo "1) Let's Encrypt (默认)"
echo "2) Buypass"
echo "3) ZeroSSL"
read -p "请输入选项 [1-3] (默认: 1): " CA_OPTION

# 如果用户直接回车，则使用Let's Encrypt
CA_OPTION=${CA_OPTION:-1}

# 根据用户选择设置CA
case $CA_OPTION in
    1)
        CA_SERVER="letsencrypt"
        ;;
    2)
        CA_SERVER="buypass"
        ;;
    3)
        CA_SERVER="zerossl"
        ;;
    *)
        echo "无效的选项。请选择1、2或3。"
        exit 1
        ;;
esac

# 检查并安装acme.sh和socat
if [ ! -f "$ACME_PATH/acme.sh" ]; then
    curl https://get.acme.sh | sh
fi

if ! command -v socat &> /dev/null; then
    apt install socat -y || yum install socat -y
fi

# 设置默认CA
$ACME_PATH/acme.sh --set-default-ca --server $CA_SERVER

# 申请SSL证书
$ACME_PATH/acme.sh --issue -d $DOMAIN -w $WEBROOT -k ec-256 --force --insecure

# 创建目标目录（如果不存在）
if [ ! -d "$KEY_DIR" ]; then
    mkdir -p $KEY_DIR
    echo "已创建目录: $KEY_DIR"
fi

# 安装SSL证书
$ACME_PATH/acme.sh --install-cert -d $DOMAIN --ecc \
    --key-file $KEY_DIR/server.key \
    --fullchain-file $KEY_DIR/server.crt

echo "SSL证书已成功为 $DOMAIN 申请并安装到 $KEY_DIR 中"

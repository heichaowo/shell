#!/bin/bash

# 确保至少一个域名被传递
if [ -z "$1" ]; then
    echo "请提供至少一个域名。用法: $0 example.com [additional-domains...]"
    exit 1
fi

# 读取主域名和其他附加域名
DOMAIN=$1
shift  # 移除第一个参数，后面的都作为附加域名
SAN_DOMAINS="$@"

WEBROOT="/var/www/html"  # 设置为你的Web服务器的根目录路径
KEY_DIR="/etc/ssl/$DOMAIN"
ACME_PATH="$HOME/.acme.sh"

# 提示输入自定义端口，默认为80
read -p "请输入要使用的端口 (默认: 80): " CUSTOM_PORT
CUSTOM_PORT=${CUSTOM_PORT:-80}

# 显示选项菜单选择CA
echo "选择要使用的CA (证书颁发机构):"
echo "1) Let's Encrypt (默认)"
echo "2) Buypass"
echo "3) ZeroSSL"
read -p "请输入选项 [1-3] (默认: 1): " CA_OPTION

# 如果用户直接回车，则使用Let's Encrypt
CA_OPTION=${CA_OPTION:-1}

# 根据用户选择设置CA服务器
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

# 选择使用的模式，默认webroot模式
echo "选择要使用的模式:"
echo "1) standalone 模式"
echo "2) webroot 模式 (默认)"
read -p "请输入选项 [1-2] (默认: 2): " MODE_OPTION

# 如果用户直接回车，则使用webroot模式
MODE_OPTION=${MODE_OPTION:-2}

# 检查并安装acme.sh和socat
if [ ! -f "$ACME_PATH/acme.sh" ]; then
    curl https://get.acme.sh | sh
fi

if ! command -v socat &> /dev/null; then
    apt install socat -y || yum install socat -y
fi

# 如果选择的是 Buypass 或 ZeroSSL，则先注册账户
if [ "$CA_SERVER" = "buypass" ] || [ "$CA_SERVER" = "zerossl" ]; then
    $ACME_PATH/acme.sh --register-account -m "${RANDOM}@dedsec.cc" --server $CA_SERVER --force --insecure
fi

# 准备 SAN 域名的参数
SAN_ARGS=""
for san in $SAN_DOMAINS; do
    SAN_ARGS="$SAN_ARGS -d $san"
done

# 使用standalone模式申请SSL证书
if [ "$MODE_OPTION" = "1" ]; then
    # 检查并添加iptables规则以打开端口（如果规则不存在）
    if ! iptables -C INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT 2>/dev/null; then
        iptables -I INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT
        echo "已添加iptables规则，允许端口 $CUSTOM_PORT"
        IPTABLES_RULE_ADDED=true
    else
        echo "iptables规则已经存在，允许端口 $CUSTOM_PORT"
        IPTABLES_RULE_ADDED=false
    fi

    $ACME_PATH/acme.sh --issue -d $DOMAIN $SAN_ARGS --standalone -k ec-256 --force --insecure --httpport $CUSTOM_PORT --server $CA_SERVER

    # 如果脚本中添加了iptables规则，则删除该规则
    if [ "$IPTABLES_RULE_ADDED" = true ]; then
        iptables -D INPUT -p tcp --dport $CUSTOM_PORT -j ACCEPT
        echo "已删除iptables规则，关闭端口 $CUSTOM_PORT"
    fi

# 使用webroot模式申请SSL证书（默认）
elif [ "$MODE_OPTION" = "2" ]; then
    $ACME_PATH/acme.sh --issue -d $DOMAIN $SAN_ARGS -w $WEBROOT -k ec-256 --force --insecure --server $CA_SERVER
else
    echo "无效的选项。请选择1或2。"
    exit 1
fi

# 创建目标目录（如果不存在）
if [ ! -d "$KEY_DIR" ]; then
    mkdir -p $KEY_DIR
    echo "已创建目录: $KEY_DIR"
fi

# 安装SSL证书
$ACME_PATH/acme.sh --install-cert -d $DOMAIN --ecc \
    --key-file $KEY_DIR/server.key \
    --fullchain-file $KEY_DIR/server.crt

echo "SSL证书已成功为 $DOMAIN 及其SAN域名申请并安装到 $KEY_DIR 中"

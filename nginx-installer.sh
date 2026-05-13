#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 权限运行此脚本 (使用 sudo)"
  exit 1
fi

# 定义变量
NGINX_KEYRING="/usr/share/keyrings/nginx-archive-keyring.gpg"
NGINX_LIST="/etc/apt/sources.list.d/nginx.list"
DEBIAN_CODENAME=$(lsb_release -cs)
NGINX_BACKUP_DIR="/etc/nginx.bak"

echo "开始安装最新版 Nginx..."

# 步骤 1：更新软件包索引
echo "更新软件包索引..."
apt update

# 步骤 2：备份现有 Nginx 配置（如果存在）
if [ -d "/etc/nginx" ]; then
  echo "备份现有 Nginx 配置到 $NGINX_BACKUP_DIR..."
  cp -r /etc/nginx $NGINX_BACKUP_DIR
fi

# 步骤 3：移除现有 Nginx 安装（如果存在）
if dpkg -l | grep -q nginx; then
  echo "移除现有 Nginx 安装..."
  apt remove --purge nginx nginx-common -y
  apt autoremove -y
fi

# 步骤 4：安装必要工具
echo "安装 curl、gnupg2 和 lsb-release..."
apt install curl gnupg2 ca-certificates lsb-release -y

# 步骤 5：下载并添加 Nginx GPG 密钥
echo "添加 Nginx 官方 GPG 密钥..."
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o $NGINX_KEYRING

# 步骤 6：添加 Nginx 官方稳定版仓库
echo "添加 Nginx 官方稳定版仓库..."
echo "deb [signed-by=$NGINX_KEYRING] http://nginx.org/packages/debian $DEBIAN_CODENAME nginx" > $NGINX_LIST

# 步骤 7：设置仓库优先级
echo "设置 Nginx 仓库优先级..."
echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900" > /etc/apt/preferences.d/99nginx

# 步骤 8：更新软件包索引并安装 Nginx
echo "更新软件包索引并安装最新版 Nginx..."
apt update
apt install nginx -y

# 步骤 9：验证 Nginx 安装
if command -v nginx >/dev/null 2>&1; then
  echo "Nginx 安装成功！版本信息："
  nginx -v
else
  echo "Nginx 安装失败，请检查错误日志。"
  exit 1
fi

# 步骤 10：恢复备份的配置文件（如果存在）
if [ -d "$NGINX_BACKUP_DIR" ]; then
  echo "恢复 Nginx 配置文件..."
  cp -r $NGINX_BACKUP_DIR/* /etc/nginx/
fi

# 步骤 11：测试 Nginx 配置
echo "测试 Nginx 配置文件..."
nginx -t

# 步骤 12：启动并启用 Nginx 服务
echo "启动并启用 Nginx 服务..."
systemctl start nginx
systemctl enable nginx

# 步骤 13：检查 Nginx 服务状态
echo "检查 Nginx 服务状态..."
if systemctl is-active --quiet nginx; then
  echo "Nginx 服务正在运行！"
else
  echo "Nginx 服务启动失败，请检查 /var/log/nginx/error.log"
  exit 1
fi

echo "安装完成！Nginx 现已运行，配置文件位于 /etc/nginx/"

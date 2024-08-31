#!/bin/bash

# GitHub 仓库页面
repo_url="https://github.com/XTLS/Xray-core/releases"

# 获取最新版本号，标记为 'Latest'
# 根据提供的 HTML 片段更新正则表达式
version=$(curl -s $repo_url | grep -oP '(?<=href="/XTLS/Xray-core/releases/tag/)\w+\.\d+\.\d+' | head -n1)

# 检查是否成功获取版本号
if [ -z "$version" ]; then
  echo "Failed to find the latest version number."
  exit 1
fi

# 构建完整的下载链接
full_url="https://github.com/XTLS/Xray-core/releases/download/${version}/Xray-linux-64.zip"

# 下载最新的 zip 文件
wget $full_url -O /tmp/Xray-linux-64.zip

# 检查是否下载成功
if [ $? -ne 0 ]; then
  echo "Failed to download the file."
  exit 1
fi

# 停止 x-ui 服务以确保可以替换文件
systemctl stop x-ui

# 解压 zip 文件直接到目标目录，自动覆盖已存在的文件
unzip -o /tmp/Xray-linux-64.zip -d /usr/local/x-ui/bin/

# 检查解压是否成功
if [ $? -ne 0 ]; then
  echo "Failed to unzip the file."
  exit 1
fi

# 重命名 xray 为 xray-linux-amd64
mv /usr/local/x-ui/bin/xray /usr/local/x-ui/bin/xray-linux-amd64

# 重启 x-ui 服务
systemctl start x-ui

# 清理临时文件
rm -rf /tmp/Xray-linux-64.zip

echo "Xray has been updated and x-ui service restarted."

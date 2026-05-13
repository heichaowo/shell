#!/bin/bash

set -e

# 检查系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "无法确定操作系统类型。"
    exit 1
fi

# 根据系统类型选择内核
if [ "$OS" == "debian" ]; then
    echo "检测到 Debian 系统，优先使用 Cloud Kernel..."
    if ! dpkg -l | grep -q "linux-image-cloud-amd64"; then
        echo "正在安装 Cloud Kernel..."
        sudo apt update
        sudo apt install -y linux-image-cloud-amd64
    else
        echo "Cloud Kernel 已安装。"
    fi
    DEFAULT_KERNEL="Debian GNU/Linux with Linux.*cloud-amd64"

elif [ "$OS" == "ubuntu" ]; then
    echo "检测到 Ubuntu 系统，优先使用 KVM Kernel..."
    if ! dpkg -l | grep -q "linux-image-kvm"; then
        echo "正在安装 KVM Kernel..."
        sudo apt update
        sudo apt install -y linux-image-kvm
    else
        echo "KVM Kernel 已安装。"
    fi
    DEFAULT_KERNEL="Ubuntu, with Linux.*kvm"

else
    echo "不支持的操作系统：$OS"
    exit 1
fi

# 设置 GRUB 默认内核
echo "正在设置 GRUB 默认内核..."
GRUB_ENTRY=$(grep -P "$DEFAULT_KERNEL" /boot/grub/grub.cfg | head -n 1 | sed -E 's/menuentry "(.*)" --class.*/\1/')
if [ -n "$GRUB_ENTRY" ]; then
    sudo grub-set-default "$GRUB_ENTRY"
    sudo update-grub
    echo "GRUB 默认内核已设置为：$GRUB_ENTRY"
else
    echo "未找到匹配的内核条目，无法设置 GRUB 默认内核。"
    exit 1
fi

# 提示重启
echo "设置完成，请重启系统以使用新的内核。"
read -p "是否立即重启？ [y/N]: " REBOOT
if [[ "$REBOOT" =~ ^[Yy]$ ]]; then
    sudo reboot
else
    echo "请稍后手动重启系统。"
fi

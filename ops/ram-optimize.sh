#!/bin/bash

# 1. 在 /etc/sysctl.conf 的最后一行添加 vm.swappiness=10 和 vm.vfs_cache_pressure=50
# 检查 sysctl.conf 中是否已经存在 vm.swappiness 配置
grep -q "^vm.swappiness=" /etc/sysctl.conf
if [ $? -eq 0 ]; then
    # 如果存在，则替换成 vm.swappiness=10
    sudo sed -i 's/^vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.conf
else
    # 如果不存在，则追加到文件末尾
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
fi

# 检查 sysctl.conf 中是否已经存在 vm.vfs_cache_pressure 配置
grep -q "^vm.vfs_cache_pressure=" /etc/sysctl.conf
if [ $? -eq 0 ]; then
    # 如果存在，则替换成 vm.vfs_cache_pressure=50
    sudo sed -i 's/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf
else
    # 如果不存在，则追加到文件末尾
    echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
fi

# 使 sysctl.conf 中的更改立即生效
sudo sysctl -p

# 2. 获取系统的总内存大小（以 MB 为单位）
mem_size=$(free -m | awk '/^Mem:/{print $2}')

# 获取当前的 swap 分区大小
current_swap=$(free -m | awk '/^Swap:/{print $2}')

# 如果当前 swap 大小小于内存大小，重新创建 swap 文件
if [ "$current_swap" -lt "$mem_size" ]; then
    echo "Current swap size is smaller than memory size. Reconfiguring swap."

    # 关闭现有的 swap
    sudo swapoff -a

    # 删除旧的 swap 文件（假设 swap 文件位于 /swapfile，如果是其他位置，请调整路径）
    sudo rm -f /swapfile

    # 创建一个新的 swap 文件，大小与系统内存相等
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$mem_size

    # 设置正确的权限
    sudo chmod 600 /swapfile

    # 将 swap 文件格式化为 swap
    sudo mkswap /swapfile

    # 启用新的 swap
    sudo swapon /swapfile

    # 将新的 swap 文件信息写入 /etc/fstab 以便系统重启时生效
    sudo sed -i '/swapfile/d' /etc/fstab
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    echo "Swap size set to $mem_size MB."
else
    echo "Current swap size is already equal to or greater than memory size. No changes made."
fi

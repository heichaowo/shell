#!/bin/bash

# 检查是否提供了命令行参数
if [ $# -eq 0 ]; then
  echo "Usage: $0 <size>"
  echo "Example: $0 1G"
  exit 1
fi

# 获取命令行参数作为swap大小
swap_size=$1

# 确定swap文件的位置
swap_file="/swapfile"

# 使用fallocate创建swap文件，根据用户指定的大小
sudo fallocate -l $swap_size $swap_file

# 设置文件权限为只有root可读写
sudo chmod 600 $swap_file

# 格式化文件为swap
sudo mkswap $swap_file

# 启用swap文件
sudo swapon $swap_file

# 检查swap是否成功启用
echo "Swap status:"
sudo swapon --show

# 将swap文件永久化到fstab中，以便开机时自动挂载
echo "$swap_file none swap sw 0 0" | sudo tee -a /etc/fstab

echo "Swap file of $swap_size created and enabled."

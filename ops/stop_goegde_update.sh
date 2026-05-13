#!/bin/bash

# 要添加的条目
entries=(
    "127.0.0.1 goedge.cn"
    "127.0.0.1 goedge.cloud"
)

# /etc/hosts文件路径
hosts_file="/etc/hosts"

# 检查每个条目是否已经存在于hosts文件中，如果不存在则添加
for entry in "${entries[@]}"; do
    if ! grep -q "$entry" "$hosts_file"; then
        echo "$entry" | sudo tee -a "$hosts_file" > /dev/null
        echo "Added: $entry"
    else
        echo "Entry already exists: $entry"
    fi
done

echo "Done."

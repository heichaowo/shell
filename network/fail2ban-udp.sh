#!/bin/bash

# 安装 fail2ban
echo "Installing fail2ban..."
apt update && apt install -y fail2ban

# 创建自定义 fail2ban 规则目录
echo "Configuring fail2ban for UDP monitoring..."
JAIL_LOCAL="/etc/fail2ban/jail.local"
FILTER_DIR="/etc/fail2ban/filter.d"
UDP_FILTER="$FILTER_DIR/udp-abuse.conf"

# 配置 fail2ban 监控 UDP 流量规则
cat > "$UDP_FILTER" << 'EOF'
[Definition]
# Fail2ban filter for UDP abuse
failregex = .* SRC=<HOST> .* DPT=[0-9]+ .* UDP
ignoreregex =
EOF

# 配置 fail2ban jail.local 文件
cat >> "$JAIL_LOCAL" << 'EOF'

[udp]
enabled  = true
filter   = udp
action   = iptables[name=udp, port=any, protocol=udp]
logpath  = /var/log/iptables.log
maxretry = 5
bantime  = 3600
findtime = 300
EOF

# 配置 iptables 日志
IPTABLES_RULE_LOG="/etc/rsyslog.d/10-iptables.conf"
cat > "$IPTABLES_RULE_LOG" << 'EOF'
# Log UDP traffic to /var/log/iptables.log
:msg, contains, "UDP" -/var/log/iptables.log
& stop
EOF

# 重新加载 rsyslog 配置
echo "Reloading rsyslog configuration..."
systemctl restart rsyslog

# 配置 iptables 规则记录 UDP 流量
echo "Adding iptables rules to log UDP packets..."
iptables -N LOGGING
iptables -I INPUT 3 -p udp -m state --state NEW -j ACCEPT
iptables -A INPUT -i tailscale0 -j ACCEPT
iptables -A INPUT -p udp -j LOGGING
iptables -A LOGGING -m limit --limit 2/min -j LOG --log-prefix "UDP Packet: " --log-level 7
iptables -A LOGGING -j DROP

# 保存 iptables 规则
echo "Saving iptables rules..."
netfilter-persistent save

# 启动 fail2ban 服务
echo "Starting fail2ban service..."
systemctl enable fail2ban
systemctl restart fail2ban

echo "Fail2ban UDP abuse protection setup completed."

#!/bin/bash

# install iptables-persistent
apt install iptables-persistent

## Flush existing rules(include nat rules) and set default policies
iptables -F
iptables -X
iptables -t nat -F

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow ICMP, SSH, HTTP, and HTTPS
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 10000 -j ACCEPT
iptables -A INPUT -p tcp --dport 10443 -j ACCEPT

# Allow UDP 443
iptables -A INPUT -p udp --dport 443 -j ACCEPT

# Allow related and established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Deny other input
iptables -P INPUT DROP

# Allow all output 
iptables -P OUTPUT ACCEPT

# Save the rules
netfilter-persistent save

# Output the rules
iptables -L
iptables -t nat -nL --line

#!/bin/bash

# install iptables-persistent
apt install iptables-persistent

# Flush existing rules and set default policies
iptables -F
iptables -X

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow SSH, HTTP, and HTTPS and Cloudflare HTTPS port
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 2053 -j ACCEPT
iptables -A INPUT -p tcp --dport 2083 -j ACCEPT
iptables -A INPUT -p tcp --dport 2087 -j ACCEPT
iptables -A INPUT -p tcp --dport 2096 -j ACCEPT
iptables -A INPUT -p tcp --dport 8443 -j ACCEPT

# Allow UDP 443
iptables -A INPUT -p udp --dport 443 -j ACCEPT

# Allow a range of UDP ports (20000-50000)
iptables -A INPUT -p udp --dport 20000:50000 -j ACCEPT

# Allow related and established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Deny other input
iptables -P INPUT DROP

# Allow all output 
iptables -P OUTPUT ACCEPT

# NAT rule for UDP port redirection
iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :443

# Save the rules
netfilter-persistent save

# Output the rules
iptables -L
iptables -t nat -nL --line

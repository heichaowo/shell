#!/bin/bash

# Flush existing rules and set default policies
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback traffic
iptables -A INPUT -i lo -j ACCEPT

# Allow SSH, HTTP, and HTTPS
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow a range of UDP ports (20000-50000)
iptables -A INPUT -p udp --dport 20000:50000 -j ACCEPT

# Allow related and established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# NAT rule for UDP port redirection
iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :443

# Save the rules
netfilter-persistent save

# Output the rules
iptables -L

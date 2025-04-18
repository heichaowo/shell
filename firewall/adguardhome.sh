#!/bin/bash

# plain DNS
#iptables -A INPUT -p tcp --dport 53 -j ACCEPT
#iptables -A INPUT -p udp --dport 53 -j ACCEPT

# DHCP server
#iptables -A INPUT -p udp --dport 67 -j ACCEPT
#iptables -A INPUT -p tcp --dport 68 -j ACCEPT
#iptables -A INPUT -p udp --dport 68 -j ACCEPT

# DNS-over-TLS⁠ server
iptables -A INPUT -p tcp --dport 853 -j ACCEPT

# DNS-over-QUIC⁠ server
iptables -A INPUT -p udp --dport 784 -j ACCEPT
iptables -A INPUT -p udp --dport 853 -j ACCEPT
iptables -A INPUT -p udp --dport 8853 -j ACCEPT

# DNSCrypt⁠ server
iptables -A INPUT -p tcp --dport 5443 -j ACCEPT
iptables -A INPUT -p udp --dport 5443 -j ACCEPT

# Save the rules
netfilter-persistent save

# Output the rules
iptables -L
iptables -t nat -nL --line

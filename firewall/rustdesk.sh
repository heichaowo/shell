#!/bin/bash
iptables -A INPUT -p tcp --dport 21114 -j ACCEPT
iptables -A INPUT -p tcp --dport 21115 -j ACCEPT
iptables -A INPUT -p tcp --dport 21116 -j ACCEPT
iptables -A INPUT -p tcp --dport 21117 -j ACCEPT
iptables -A INPUT -p tcp --dport 21118 -j ACCEPT
iptables -A INPUT -p tcp --dport 21119 -j ACCEPT
iptables -A INPUT -p udp --dport 21115 -j ACCEPT

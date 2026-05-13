# Allow a range of UDP ports (20000-50000)
iptables -A INPUT -p udp --dport 20000:50000 -j ACCEPT

# NAT rule for UDP port redirection
iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j DNAT --to-destination :443

# Save the rules
netfilter-persistent save

# Output the rules
iptables -L
iptables -t nat -nL --line

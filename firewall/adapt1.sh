#Allow several ports
iptables -A INPUT -p tcp --dport 51821 -j ACCEPT
iptables -A INPUT -p udp --dport 51820 -j ACCEPT

# Save the rules
netfilter-persistent save

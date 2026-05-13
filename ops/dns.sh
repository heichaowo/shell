#!/bin/bash

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Update package list and install cloudflared
echo "Updating package list and installing cloudflared..."
sudo apt update
sudo apt install -y cloudflared

# Create cloudflared config file
echo "Creating cloudflared configuration..."
cat <<EOL > /etc/cloudflared/config.yml
proxy-dns: true
proxy-dns-port: 5053
proxy-dns-upstream:
 - https://dns.dedsec.cc/dns-query
 - https://1.1.1.1/dns-query
EOL

# Enable and start cloudflared service
echo "Enabling and starting cloudflared service..."
sudo systemctl enable cloudflared
sudo systemctl start cloudflared

# Backup current resolv.conf and configure system to use cloudflared
echo "Configuring system DNS to use cloudflared..."
cp /etc/resolv.conf /etc/resolv.conf.backup
echo "nameserver 127.0.0.1" > /etc/resolv.conf

# Verify configuration
echo "Verifying DNS configuration..."
dig @127.0.0.1 google.com

echo "DNS over HTTPS (DoH) configuration completed."

#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Backup the current resolv.conf
cp /etc/resolv.conf /etc/resolv.conf.backup

# Write new DNS settings to resolv.conf
echo "nameserver dns.dedsec.cc" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Verify the changes
echo "The DNS settings have been updated to Private DNS"
cat /etc/resolv.conf

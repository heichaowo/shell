#!/bin/bash

# 1. 干掉 snap
snap list
snap remove --purge $(snap list | awk 'NR>1{print $1}') 2>/dev/null
apt purge -y snapd
apt-mark hold snapd
rm -rf ~/snap /var/cache/snapd

# 2. 干掉无用服务
systemctl disable --now multipathd apport ModemManager ubuntu-advantage-tools 2>/dev/null

# 3. 清理
apt autoremove --purge -y
apt autoclean

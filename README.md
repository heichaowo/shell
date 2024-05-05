# 来源
https://github.com/TinrLin/sing-box_-tutorial/tree/main/Hysteria2

一个一个复制命令很麻烦，就写成了shell自己用了

脚本并非完全复制来源，根据我自己的需求有小做修改，请注意看shell里的注释

# 使用
wget -N --no-check-certificate "https://raw.githubusercontent.com/heichaowo/shell/main/firewall/firewall.sh" && sudo chmod +x firewall.sh && sudo ./firewall.sh

wget -N --no-check-certificate "https://raw.githubusercontent.com/heichaowo/shell/main/firewall/adapt.sh" && sudo chmod +x adapt.sh && sudo ./adapt.sh

wget -N --no-check-certificate "https://raw.githubusercontent.com/heichaowo/shell/main/iptables/iptables/iptables.sh" && sudo chmod +x iptables.sh && sudo ./iptables.sh

bash <(curl -fsSL https://raw.githubusercontent.com/heichaowo/shell/main/miner.sh/)

wget -N --no-check-certificate "https://raw.githubusercontent.com/heichaowo/shell/main/swap.sh" && sudo chmod +x swap.sh && sudo ./swap.sh

swap.sh 后面可以加上1g,或是需要的swap大小

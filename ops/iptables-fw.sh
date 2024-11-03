#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: iptables Port forwarding
#	Version: 0.0.2
#	Author: heichaowo
#=================================================
sh_ver="0.0.2"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_iptables(){
	iptables_exist=$(iptables -V)
	[[ ${iptables_exist} = "" ]] && echo -e "${Error} 没有安装iptables，请检查 !" && exit 1
}

check_ip6tables(){
	ip6tables_exist=$(ip6tables -V)
	if [[ ${forwarding_ip} =~ ":" ]]; then
		if [[ ${ip6tables_exist} = "" ]]; then
			echo -e "${Info} 检测到未安装 ip6tables，开始安装..."
			if [[ ${release} == "centos" ]]; then
				yum install -y ip6tables
			else
				apt-get install -y ip6tables
			fi
			ip6tables_exist=$(ip6tables -V)
			if [[ ${ip6tables_exist} = "" ]]; then
				echo -e "${Error} 安装ip6tables失败，请检查 !" && exit 1
			else
				echo -e "${Info} ip6tables 安装完成 !"
			fi
		fi
	fi
}

Add_iptables(){
	if [[ ${forwarding_ip} =~ ":" ]]; then
		ip6tables -t nat -A PREROUTING -p "$1" --dport "${local_port}" -j DNAT --to-destination "${forwarding_ip}:${forwarding_port}"
		ip6tables -t nat -A POSTROUTING -p "$1" -d "${forwarding_ip}" --dport "${forwarding_port_1}" -j MASQUERADE
		ip6tables -I INPUT -m state --state NEW -m "$1" -p "$1" --dport "${local_port}" -j ACCEPT
	else
		iptables -t nat -A PREROUTING -p "$1" --dport "${local_port}" -j DNAT --to-destination "${forwarding_ip}:${forwarding_port}"
		iptables -t nat -A POSTROUTING -p "$1" -d "${forwarding_ip}" --dport "${forwarding_port_1}" -j MASQUERADE
		iptables -I INPUT -m state --state NEW -m "$1" -p "$1" --dport "${local_port}" -j ACCEPT
	fi
}

Del_iptables(){
	if [[ ${forwarding_ip} =~ ":" ]]; then
		ip6tables -t nat -D POSTROUTING "$2"
		ip6tables -t nat -D PREROUTING "$2"
		ip6tables -D INPUT -m state --state NEW -m "$1" -p "$1" --dport "${forwarding_listen}" -j ACCEPT
	else
		iptables -t nat -D POSTROUTING "$2"
		iptables -t nat -D PREROUTING "$2"
		iptables -D INPUT -m state --state NEW -m "$1" -p "$1" --dport "${forwarding_listen}" -j ACCEPT
	fi
}

Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		if [[ ${forwarding_ip} =~ ":" ]]; then
			service ip6tables save
		else
			service iptables save
		fi
	else
		if [[ ${forwarding_ip} =~ ":" ]]; then
			ip6tables-save > /etc/ip6tables.up.rules
		else
			iptables-save > /etc/iptables.up.rules
		fi
	fi
}

check_sys
check_iptables
check_ip6tables
# ... rest of the script

#!/usr/bin/env bash 
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: iptables Port forwarding with MASQUERADE support
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
	if [[ ${ip6tables_exist} = "" ]]; then
		echo -e "${Info} 检测到未安装 ip6tables，开始安装..."
		if [[ ${release} == "centos" ]]; then
			yum update
			yum install -y ip6tables
		else
			apt-get update
			apt-get install -y ip6tables
		fi
		ip6tables_exist=$(ip6tables -V)
		if [[ ${ip6tables_exist} = "" ]]; then
			echo -e "${Error} 安装ip6tables失败，请检查 !" && exit 1
		else
			echo -e "${Info} ip6tables 安装完成 !"
		fi
	fi
}

Add_forwarding(){
	check_iptables
	Set_Config
	local_port=$(echo ${local_port} | sed 's/-/:/g')
	forwarding_port_1=$(echo ${forwarding_port} | sed 's/-/:/g')
	if [[ ${forwarding_type} == "TCP" ]]; then
		Add_iptables "tcp"
	elif [[ ${forwarding_type} == "UDP" ]]; then
		Add_iptables "udp"
	elif [[ ${forwarding_type} == "TCP+UDP" ]]; then
		Add_iptables "tcp"
		Add_iptables "udp"
	fi
	Save_iptables
	clear && echo && echo -e "—————————————————————————————————————
	iptables 端口转发规则配置完成 !\n
	本地监听端口    : ${Green_font_prefix}${local_port}${Font_color_suffix}
	服务器 IP	: ${Green_font_prefix}${local_ip}${Font_color_suffix}\n
	欲转发的端口    : ${Green_font_prefix}${forwarding_port_1}${Font_color_suffix}
	欲转发 IP	: ${Green_font_prefix}${forwarding_ip}${Font_color_suffix}
	转发类型	: ${Green_font_prefix}${forwarding_type}${Font_color_suffix}
—————————————————————————————————————\n"
}

Add_iptables(){
	if [[ ${forwarding_ip} =~ : ]]; then
		check_ip6tables
		ip6tables -t nat -A PREROUTING -p "$1" --dport "${local_port}" -j DNAT --to-destination "${forwarding_ip}:${forwarding_port}"
		ip6tables -t nat -A POSTROUTING -p "$1" -d "${forwarding_ip}" --dport "${forwarding_port_1}" -j MASQUERADE
		ip6tables -I INPUT -m state --state NEW -m "$1" -p "$1" --dport "${local_port}" -j ACCEPT
	else
		iptables -t nat -A PREROUTING -p "$1" --dport "${local_port}" -j DNAT --to-destination "${forwarding_ip}:${forwarding_port}"
		iptables -t nat -A POSTROUTING -p "$1" -d "${forwarding_ip}" --dport "${forwarding_port_1}" -j MASQUERADE
		iptables -I INPUT -m state --state NEW -m "$1" -p "$1" --dport "${local_port}" -j ACCEPT
	fi
}

Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
		service ip6tables save
	else
		iptables-save > /etc/iptables.up.rules
		ip6tables-save > /etc/ip6tables.up.rules
	fi
}

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	fi
}

Update_Shell(){
	sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "https://raw.githubusercontent.com/heichaowo/shell/refs/heads/main/ops/iptables-fw.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1)
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 无法链接到 Github !" && exit 0
	wget -N --no-check-certificate "https://raw.githubusercontent.com/heichaowo/shell/refs/heads/main/ops/iptables-fw.sh" && chmod +x iptables-fw.sh
	echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !(注意：因为更新方式为直接覆盖当前运行的脚本，所以可能下面会提示一些报错，无视即可)" && exit 0
}

check_sys
echo && echo -e " iptables 端口转发一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Toyo | doub.io/wlzy-20 --

 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
———————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 iptables
 ${Green_font_prefix}2.${Font_color_suffix} 清空 iptables 端口转发
———————————
 ${Green_font_prefix}3.${Font_color_suffix} 查看 iptables 端口转发
 ${Green_font_prefix}4.${Font_color_suffix} 添加 iptables 端口转发
 ${Green_font_prefix}5.${Font_color_suffix} 删除 iptables 端口转发
———————————
注意：初次使用前请请务必执行 ${Green_font_prefix}1. 安装 iptables${Font_color_suffix}(不仅仅是安装)" && echo
read -e -p " 请输入数字 [0-5]:" num
case "$num" in
	0)
	Update_Shell
	;;
	1)
	install_iptables
	;;
	2)
	Uninstall_forwarding
	;;
	3)
	View_forwarding
	;;
	4)
	Add_forwarding
	;;
	5)
	Del_forwarding
	;;
	*)
	echo "请输入正确数字 [0-5]"
	;;
esac

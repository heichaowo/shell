#!/usr/bin/env bash 
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS/Debian/Ubuntu
#	Description: iptables Port forwarding with MASQUERADE
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
check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
}
install_iptables(){
	iptables_exist=$(iptables -V)
	if [[ ${iptables_exist} != "" ]]; then
		echo -e "${Info} 已经安装iptables，继续..."
	else
		echo -e "${Info} 检测到未安装 iptables，开始安装..."
		if [[ ${release}  == "centos" ]]; then
			yum update
			yum install -y iptables iptables-services
		else
			apt-get update
			apt-get install -y iptables
		fi
		iptables_exist=$(iptables -V)
		if [[ ${iptables_exist} = "" ]]; then
			echo -e "${Error} 安装iptables失败，请检查 !" && exit 1
		else
			echo -e "${Info} iptables 安装完成 !"
		fi
	fi
	echo -e "${Info} 开始配置 iptables !"
	Set_iptables
	echo -e "${Info} iptables 配置完毕 !"
}
Set_forwarding_port(){
	read -e -p "请输入 iptables 欲转发至的 远程端口 [1-65535] (支持端口段 如 2333-6666, 被转发服务器):" forwarding_port
	[[ -z "${forwarding_port}" ]] && echo "取消..." && exit 1
	echo && echo -e "	欲转发端口 : ${Red_font_prefix}${forwarding_port}${Font_color_suffix}" && echo
}
Set_forwarding_ip(){
	read -e -p "请输入 iptables 欲转发至的 远程IP(被转发服务器):" forwarding_ip
	[[ -z "${forwarding_ip}" ]] && echo "取消..." && exit 1
	echo && echo -e "	欲转发服务器IP : ${Red_font_prefix}${forwarding_ip}${Font_color_suffix}" && echo
	if [[ ${forwarding_ip} =~ ":" ]]; then
		ipv6=1
	else
		ipv6=0
	fi
	if [[ ${ipv6} -eq 1 ]]; then
		install_ip6tables
	fi
}
install_ip6tables(){
	ip6tables_exist=$(ip6tables -V)
	if [[ ${ip6tables_exist} != "" ]]; then
		echo -e "${Info} 已经安装ip6tables，继续..."
	else
		echo -e "${Info} 检测到未安装 ip6tables，开始安装..."
		if [[ ${release}  == "centos" ]]; then
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
}
Set_local_port(){
	echo -e "请输入 iptables 本地监听端口 [1-65535] (支持端口段 如 2333-6666)"
	read -e -p "(默认端口: ${forwarding_port}):" local_port
	[[ -z "${local_port}" ]] && local_port="${forwarding_port}"
	echo && echo -e "	本地监听端口 : ${Red_font_prefix}${local_port}${Font_color_suffix}" && echo
}
Set_local_ip(){
	read -e -p "请输入 本服务器的 网卡IP(注意是网卡绑定的IP，而不仅仅是公网IP，回车自动检测外网IP):" local_ip
	if [[ -z "${local_ip}" ]]; then
		local_ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
		if [[ -z "${local_ip}" ]]; then
			echo "${Error} 无法检测到本服务器的公网IP，请手动输入"
			read -e -p "请输入 本服务器的 网卡IP(注意是网卡绑定的IP，而不仅仅是公网IP):" local_ip
			[[ -z "${local_ip}" ]] && echo "取消..." && exit 1
		fi
	fi
	echo && echo -e "	本服务器IP : ${Red_font_prefix}${local_ip}${Font_color_suffix}" && echo
}
Set_forwarding_type(){
	echo -e "请输入数字 来选择 iptables 转发类型:
 1. TCP
 2. UDP
 3. TCP+UDP\n"
	read -e -p "(默认: TCP+UDP):" forwarding_type_num
	[[ -z "${forwarding_type_num}" ]] && forwarding_type_num="3"
	if [[ ${forwarding_type_num} == "1" ]]; then
		forwarding_type="TCP"
	elif [[ ${forwarding_type_num} == "2" ]]; then
		forwarding_type="UDP"
	elif [[ ${forwarding_type_num} == "3" ]]; then
		forwarding_type="TCP+UDP"
	else
		forwarding_type="TCP+UDP"
	fi
}
Set_Config(){
	Set_forwarding_port
	Set_forwarding_ip
	Set_local_port
	Set_local_ip
	Set_forwarding_type
	echo && echo -e "——————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————————

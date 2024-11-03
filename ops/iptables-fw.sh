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
	echo && echo -e "——————————————————————————————————————————————————————————————————————"
	read -e -p "请按任意键继续，如有配置错误请使用 Ctrl+C 退出。" var
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
	clear && echo && echo -e "——————————————————————————————————————————————————————————————————————"
	echo -e "iptables 端口转发规则配置完成 !\n"
	echo -e "本地监听端口    : ${Green_font_prefix}${local_port}${Font_color_suffix}"
	echo -e "服务器 IP	: ${Green_font_prefix}${local_ip}${Font_color_suffix}\n"
	echo -e "欲转发的端口    : ${Green_font_prefix}${forwarding_port_1}${Font_color_suffix}"
	echo -e "欲转发 IP	: ${Green_font_prefix}${forwarding_ip}${Font_color_suffix}"
	echo -e "转发类型	: ${Green_font_prefix}${forwarding_type}${Font_color_suffix}"
	echo -e "——————————————————————————————————————————————————————————————————————\n"
}
Save_iptables(){
	if [[ ${release} == "centos" ]]; then
		service iptables save
	else
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	sysctl -p
	if [[ ${release} == "centos" ]]; then
		service iptables save
		chkconfig --level 2345 iptables on
	else
		iptables-save > /etc/iptables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
Update_Shell(){
	sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "https://raw.githubusercontent.com/heichaowo/shell/refs/heads/main/ops/iptables-fw.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/"//g'|head -1)
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 无法链接到 Github !" && exit 0
	wget -N --no-check-certificate "https://raw.githubusercontent.com/heichaowo/shell/refs/heads/main/ops/iptables-fw.sh" && chmod +x iptables-fw.sh
	echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !(注意：因为更新方式为直接覆盖当前运行的脚本，所以可能下面会提示一些报错，无视即可)" && exit 0
}
check_sys
echo && echo -e " iptables 端口转发一键管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Nya | community.nya.ae --
  
 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 iptables
 ${Green_font_prefix}2.${Font_color_suffix} 清空 iptables 端口转发
————————————
 ${Green_font_prefix}3.${Font_color_suffix} 查看 iptables 端口转发
 ${Green_font_prefix}4.${Font_color_suffix} 添加 iptables 端口转发
 ${Green_font_prefix}5.${Font_color_suffix} 删除 iptables 端口转发
————————————
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

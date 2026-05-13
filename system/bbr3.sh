#!/usr/bin/env bash

# 颜色定义
Red="\033[31m"
Green="\033[32m"
Yellow="\033[33m"
Blue="\033[34m"
Magenta="\033[35m"
Cyan="\033[36m"
Reset="\033[0m"

# 消息类型定义
Info="${Green}[信息]${Reset}"
Error="${Red}[错误]${Reset}"
Warning="${Yellow}[警告]${Reset}"
Success="${Cyan}[成功]${Reset}"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Error} 此脚本需要root权限运行！"
        exit 1
    fi
}

# 移除旧的BBR和LotServer配置
remove_bbr_lotserver() {
    echo -e "${Info} 正在清理旧的BBR和LotServer配置..."
    
    # 停止并禁用可能的LotServer服务
    systemctl stop lotserver 2>/dev/null
    systemctl disable lotserver 2>/dev/null
    
    # 移除LotServer相关文件
    rm -rf /appex 2>/dev/null
    rm -rf /etc/lotserver 2>/dev/null
    
    echo -e "${Success} 旧配置清理完成"
}

# 备份并去重sysctl配置文件
backup_and_deduplicate_sysctl() {
    local sysctl_file="/etc/sysctl.d/99-sysctl.conf"
    local backup_file="/etc/sysctl.d/99-sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    echo -e "${Info} 正在处理sysctl配置文件..."
    
    # 创建备份
    if [[ -f "$sysctl_file" ]]; then
        cp "$sysctl_file" "$backup_file"
        echo -e "${Info} 已创建配置文件备份：$backup_file"
        
        # 去重处理 - 移除重复的网络相关配置
        echo -e "${Info} 正在去重网络配置参数..."
        
        # 创建临时文件
        local temp_file=$(mktemp)
        
        # 移除已存在的网络优化相关配置
        grep -v -E "^[[:space:]]*net\.(core\.default_qdisc|ipv4\.tcp_congestion_control|ipv4\.tcp_ecn)" "$sysctl_file" > "$temp_file"
        
        # 将去重后的内容写回原文件
        mv "$temp_file" "$sysctl_file"
        
        echo -e "${Success} 配置文件去重完成"
    else
        # 如果文件不存在，创建空文件
        touch "$sysctl_file"
        echo -e "${Info} 创建新的sysctl配置文件"
    fi
}

# 应用网络配置
apply_network_config() {
    local qdisc="$1"
    local congestion_control="$2"
    local enable_ecn="$3"
    local config_name="$4"
    
    echo -e "${Info} 正在应用 ${Magenta}$config_name${Reset} 配置..."
    
    # 添加新的配置到sysctl文件
    cat >> /etc/sysctl.d/99-sysctl.conf << EOF

# $config_name 网络优化配置 - $(date +"%Y-%m-%d %H:%M:%S")
net.core.default_qdisc = $qdisc
net.ipv4.tcp_congestion_control = $congestion_control
EOF

    # 如果启用ECN，添加ECN配置
    if [[ "$enable_ecn" == "1" ]]; then
        echo "net.ipv4.tcp_ecn = 1" >> /etc/sysctl.d/99-sysctl.conf
    fi
    
    # 应用其他网络优化参数
    cat >> /etc/sysctl.d/99-sysctl.conf << EOF
# TCP优化参数
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 65536 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.core.netdev_max_backlog = 5000
EOF
}

# 检查并加载内核模块
check_and_load_modules() {
    local qdisc="$1"
    
    echo -e "${Info} 检查并加载必要的内核模块..."
    
    # 加载BBR模块
    modprobe tcp_bbr 2>/dev/null
    
    # 根据队列算法加载相应模块
    case "$qdisc" in
        "fq_codel")
            modprobe sch_fq_codel 2>/dev/null
            ;;
        "cake")
            modprobe sch_cake 2>/dev/null
            ;;
        "fq_pie")
            modprobe sch_fq_pie 2>/dev/null
            ;;
    esac
    
    echo -e "${Success} 内核模块加载完成"
}

# 显示配置选择菜单
show_menu() {
    echo
    echo -e "${Blue}=== 网络优化配置选择 ===${Reset}"
    echo
    echo -e "${Green}1.${Reset} ${Cyan}优质线路配置${Reset} (CN2/CMIN2/9929)"
    echo -e "   └─ BBRv3 + fq_codel + ECN"
    echo -e "   └─ 适用于：优质线路，延迟低，稳定性好"
    echo
    echo -e "${Yellow}2.${Reset} ${Cyan}普通高延迟线路配置${Reset} (如RN美西DC2)"
    echo -e "   └─ BBRv3 + cake + ECN"  
    echo -e "   └─ 适用于：延迟高，可能丢包的线路"
    echo
    echo -e "${Magenta}3.${Reset} ${Cyan}直连低延迟线路配置${Reset} (163/4837/CMIN)"
    echo -e "   └─ BBRv3 + fq_pie + ECN"
    echo -e "   └─ 适用于：直连线路，延迟低但带宽一般"
    echo
    echo -e "${Red}0.${Reset} 退出脚本"
    echo
}

# 验证配置是否生效
verify_config() {
    echo -e "${Info} 验证当前网络配置..."
    
    # 显示当前拥塞控制算法
    current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | cut -d= -f2 | xargs)
    echo -e "${Info} 当前拥塞控制算法: ${Green}$current_cc${Reset}"
    
    # 显示当前队列算法
    current_qdisc=$(sysctl net.core.default_qdisc 2>/dev/null | cut -d= -f2 | xargs)
    echo -e "${Info} 当前队列调度算法: ${Green}$current_qdisc${Reset}"
    
    # 显示ECN状态
    current_ecn=$(sysctl net.ipv4.tcp_ecn 2>/dev/null | cut -d= -f2 | xargs)
    echo -e "${Info} ECN状态: ${Green}$current_ecn${Reset}"
    
    # 显示可用的拥塞控制算法
    available_cc=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)
    echo -e "${Info} 可用拥塞控制算法: ${Green}$available_cc${Reset}"
}

# 主执行函数
main() {
    check_root
    
    echo -e "${Blue}"
    echo "=================================================="
    echo "           Linux 网络优化配置脚本"
    echo "            支持多场景BBRv3配置"
    echo "=================================================="
    echo -e "${Reset}"
    
    # 显示当前配置状态
    verify_config
    
    while true; do
        show_menu
        
        read -p "请选择配置方案 [0-3]: " choice
        
        case $choice in
            1)
                echo -e "${Info} 您选择了: ${Green}优质线路配置${Reset}"
                remove_bbr_lotserver
                backup_and_deduplicate_sysctl
                check_and_load_modules "fq_codel"
                apply_network_config "fq_codel" "bbr" "1" "优质线路(CN2/CMIN2/9929)"
                ;;
            2)
                echo -e "${Info} 您选择了: ${Yellow}普通高延迟线路配置${Reset}"
                remove_bbr_lotserver
                backup_and_deduplicate_sysctl
                check_and_load_modules "cake"
                apply_network_config "cake" "bbr" "1" "高延迟线路(RN美西DC2)"
                ;;
            3)
                echo -e "${Info} 您选择了: ${Magenta}直连低延迟线路配置${Reset}"
                remove_bbr_lotserver
                backup_and_deduplicate_sysctl
                check_and_load_modules "fq_pie"
                apply_network_config "fq_pie" "bbr" "1" "直连线路(163/4837/CMIN)"
                ;;
            0)
                echo -e "${Info} 退出脚本"
                exit 0
                ;;
            *)
                echo -e "${Error} 无效选择，请输入 0-3"
                continue
                ;;
        esac
        
        # 应用配置
        echo -e "${Info} 正在应用系统配置..."
        sysctl --system >/dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo -e "${Success} 配置应用成功！"
        else
            echo -e "${Error} 配置应用时出现警告，但可能仍然有效"
        fi
        
        # 再次验证配置
        echo
        verify_config
        
        echo
        echo -e "${Success} ================================"
        echo -e "${Success} 网络优化配置已完成！"
        echo -e "${Success} 建议重启系统以确保所有配置生效"
        echo -e "${Success} ================================"
        echo
        
        read -p "是否现在重启系统？[y/N]: " reboot_choice
        case $reboot_choice in
            [Yy]|[Yy][Ee][Ss])
                echo -e "${Info} 系统将在3秒后重启..."
                sleep 3
                reboot
                ;;
            *)
                echo -e "${Warning} 请记得稍后手动重启系统以使配置完全生效"
                break
                ;;
        esac
    done
}

# 脚本入口
main "$@"

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

# 配置变量
TARGET_PORT=""
PROTOCOL="both"  # tcp, udp, both
CHINA_IPSET_NAME="china_ip"
LOG_FILE="/var/log/china_ip_block.log"
CONFIG_FILE="/etc/china-ip-block.conf"

# 读取配置文件
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        echo -e "${Info} 已加载配置文件: $CONFIG_FILE"
        echo -e "${Info} 当前配置端口: ${Green}$TARGET_PORT${Reset}"
        echo -e "${Info} 当前协议类型: ${Green}$PROTOCOL${Reset}"
    else
        echo -e "${Warning} 配置文件不存在，需要创建新配置"
        TARGET_PORT=""
        PROTOCOL="both"
    fi
}

# 保存配置到文件
save_config() {
    cat > "$CONFIG_FILE" << 'EOF_CONFIG'
# 中国IP阻断工具配置文件
# 生成时间: $(date)
TARGET_PORT="$TARGET_PORT"
PROTOCOL="$PROTOCOL"
CHINA_IPSET_NAME="$CHINA_IPSET_NAME"
LOG_FILE="$LOG_FILE"
EOF_CONFIG
    
    # 替换变量
    sed -i "s/\$TARGET_PORT/$TARGET_PORT/g" "$CONFIG_FILE"
    sed -i "s/\$PROTOCOL/$PROTOCOL/g" "$CONFIG_FILE"
    sed -i "s/\$CHINA_IPSET_NAME/$CHINA_IPSET_NAME/g" "$CONFIG_FILE"
    sed -i "s|\$LOG_FILE|$LOG_FILE|g" "$CONFIG_FILE"
    sed -i "s/\$(date)/$(date)/g" "$CONFIG_FILE"
    
    echo -e "${Success} 配置已保存到: $CONFIG_FILE"
}

# 检查root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Error} 此脚本需要root权限运行！"
        exit 1
    fi
}

# 获取协议类型
get_protocol_type() {
    while true; do
        echo
        echo -e "${Blue}=== 协议类型配置 ===${Reset}"
        
        if [[ -n "$PROTOCOL" ]]; then
            local protocol_name
            case "$PROTOCOL" in
                "tcp") protocol_name="TCP" ;;
                "udp") protocol_name="UDP" ;;
                "both") protocol_name="TCP+UDP" ;;
            esac
            echo -e "${Info} 当前协议类型: ${Green}$protocol_name${Reset}"
            echo
            echo -e "${Yellow}1.${Reset} 使用当前协议 ($protocol_name)"
            echo -e "${Yellow}2.${Reset} 修改协议类型"
            echo -e "${Red}0.${Reset} 返回"
            echo
            read -p "请选择 [0-2]: " protocol_choice
            
            case $protocol_choice in
                1)
                    echo -e "${Success} 使用协议: $protocol_name"
                    return 0
                    ;;
                2)
                    # 继续到下面的协议选择逻辑
                    ;;
                0)
                    return 1
                    ;;
                *)
                    echo -e "${Error} 无效选择"
                    continue
                    ;;
            esac
        fi
        
        echo
        echo -e "${Info} 请选择要阻断的协议类型："
        echo -e "${Green}1.${Reset} ${Cyan}TCP${Reset} - 适用于HTTP、HTTPS、SSH等服务"
        echo -e "${Green}2.${Reset} ${Cyan}UDP${Reset} - 适用于DNS、游戏服务器等"
        echo -e "${Green}3.${Reset} ${Cyan}TCP+UDP${Reset} - 同时阻断两种协议 [推荐]"
        echo -e "${Red}0.${Reset} 返回"
        echo
        read -p "协议类型 [0-3]: " input_protocol
        
        case $input_protocol in
            1)
                PROTOCOL="tcp"
                echo -e "${Success} 协议设置为: ${Green}TCP${Reset}"
                return 0
                ;;
            2)
                PROTOCOL="udp"
                echo -e "${Success} 协议设置为: ${Green}UDP${Reset}"
                return 0
                ;;
            3)
                PROTOCOL="both"
                echo -e "${Success} 协议设置为: ${Green}TCP+UDP${Reset}"
                return 0
                ;;
            0)
                return 1
                ;;
            *)
                echo -e "${Error} 无效选择，请输入 0-3"
                ;;
        esac
    done
}

# 获取用户输入的端口
get_target_port() {
    while true; do
        echo
        echo -e "${Blue}=== 端口配置 ===${Reset}"
        
        if [[ -n "$TARGET_PORT" ]]; then
            echo -e "${Info} 当前配置端口: ${Green}$TARGET_PORT${Reset}"
            echo
            echo -e "${Yellow}1.${Reset} 使用当前端口 ($TARGET_PORT)"
            echo -e "${Yellow}2.${Reset} 修改端口"
            echo -e "${Red}0.${Reset} 返回主菜单"
            echo
            read -p "请选择 [0-2]: " port_choice
            
            case $port_choice in
                1)
                    echo -e "${Success} 使用端口: $TARGET_PORT"
                    return 0
                    ;;
                2)
                    # 继续到下面的端口输入逻辑
                    ;;
                0)
                    return 1
                    ;;
                *)
                    echo -e "${Error} 无效选择"
                    continue
                    ;;
            esac
        fi
        
        echo
        echo -e "${Info} 请输入要阻断的端口号"
        echo -e "${Info} 支持格式："
        echo -e "  ${Cyan}单个端口${Reset}: 80, 443, 22"
        echo -e "  ${Cyan}端口范围${Reset}: 8000:8999, 1000-2000"
        echo -e "  ${Cyan}多个端口${Reset}: 80,443,22 或 80,443,8000:8080"
        echo
        read -p "端口 (输入 'q' 返回): " input_port
        
        if [[ "$input_port" =~ ^[qQ]$ ]]; then
            return 1
        fi
        
        # 验证端口格式
        if validate_port_format "$input_port"; then
            TARGET_PORT="$input_port"
            echo -e "${Success} 端口设置成功: ${Green}$TARGET_PORT${Reset}"
            return 0
        else
            echo -e "${Error} 端口格式无效，请重新输入"
            echo -e "${Warning} 示例: 80, 443, 8000:8080, 80,443,22"
        fi
    done
}

# 配置端口和协议
configure_port_and_protocol() {
    echo -e "${Info} 开始配置端口和协议..."
    
    # 先配置端口
    if ! get_target_port; then
        return 1
    fi
    
    # 再配置协议
    if ! get_protocol_type; then
        return 1
    fi
    
    # 保存配置
    save_config
    
    echo
    echo -e "${Success} 配置完成："
    echo -e "${Success} 端口: ${Green}$TARGET_PORT${Reset}"
    
    local protocol_name
    case "$PROTOCOL" in
        "tcp") protocol_name="TCP" ;;
        "udp") protocol_name="UDP" ;;
        "both") protocol_name="TCP+UDP" ;;
    esac
    echo -e "${Success} 协议: ${Green}$protocol_name${Reset}"
    
    return 0
}

# 验证端口格式
validate_port_format() {
    local port="$1"
    
    # 移除空格
    port=$(echo "$port" | tr -d ' ')
    
    # 检查是否为空
    if [[ -z "$port" ]]; then
        return 1
    fi
    
    # 分割多个端口
    IFS=',' read -ra port_array <<< "$port"
    
    for p in "${port_array[@]}"; do
        # 检查单个端口
        if [[ "$p" =~ ^[0-9]+$ ]]; then
            if [[ $p -lt 1 || $p -gt 65535 ]]; then
                echo -e "${Error} 端口范围必须在 1-65535 之间: $p"
                return 1
            fi
        # 检查端口范围 (支持 : 和 - 两种分隔符)
        elif [[ "$p" =~ ^[0-9]+[:|-][0-9]+$ ]]; then
            local start end
            if [[ "$p" =~ : ]]; then
                start=$(echo "$p" | cut -d: -f1)
                end=$(echo "$p" | cut -d: -f2)
            else
                start=$(echo "$p" | cut -d- -f1)
                end=$(echo "$p" | cut -d- -f2)
            fi
            
            if [[ $start -lt 1 || $start -gt 65535 || $end -lt 1 || $end -gt 65535 ]]; then
                echo -e "${Error} 端口范围必须在 1-65535 之间: $p"
                return 1
            fi
            
            if [[ $start -gt $end ]]; then
                echo -e "${Error} 起始端口不能大于结束端口: $p"
                return 1
            fi
        else
            echo -e "${Error} 无效的端口格式: $p"
            return 1
        fi
    done
    
    return 0
}

# 检查依赖
check_dependencies() {
    echo -e "${Info} 检查系统依赖..."
    
    # 检查iptables
    if ! command -v iptables &> /dev/null; then
        echo -e "${Error} 未找到iptables，正在安装..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y iptables
        elif command -v yum &> /dev/null; then
            yum install -y iptables
        elif command -v dnf &> /dev/null; then
            dnf install -y iptables
        else
            echo -e "${Error} 无法自动安装iptables，请手动安装"
            exit 1
        fi
    fi
    
    # 检查ipset
    if ! command -v ipset &> /dev/null; then
        echo -e "${Info} 未找到ipset，正在安装..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y ipset
        elif command -v yum &> /dev/null; then
            yum install -y ipset
        elif command -v dnf &> /dev/null; then
            dnf install -y ipset
        else
            echo -e "${Error} 无法自动安装ipset，请手动安装"
            exit 1
        fi
    fi
    
    # 检查curl或wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        echo -e "${Info} 未找到curl或wget，正在安装curl..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y curl
        elif command -v yum &> /dev/null; then
            yum install -y curl
        elif command -v dnf &> /dev/null; then
            dnf install -y curl
        fi
    fi
    
    echo -e "${Success} 依赖检查完成"
}

# 下载中国IP段列表
download_china_ip() {
    echo -e "${Info} 正在下载中国IP段列表..."
    
    local temp_file="/tmp/china_ip.txt"
    local sources=(
        "https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt"
        "https://ispip.clang.cn/all_cn.txt"
        "https://raw.githubusercontent.com/mayaxcn/china-ip-list/master/chnroute.txt"
    )
    
    # 尝试从多个源下载
    for source in "${sources[@]}"; do
        echo -e "${Info} 尝试从 $source 下载..."
        
        if command -v curl &> /dev/null; then
            if curl -s --connect-timeout 10 --max-time 30 "$source" -o "$temp_file"; then
                if [[ -s "$temp_file" ]]; then
                    echo -e "${Success} 成功从 $source 下载IP列表"
                    return 0
                fi
            fi
        elif command -v wget &> /dev/null; then
            if wget -q --timeout=30 --tries=2 "$source" -O "$temp_file"; then
                if [[ -s "$temp_file" ]]; then
                    echo -e "${Success} 成功从 $source 下载IP列表"
                    return 0
                fi
            fi
        fi
        
        echo -e "${Warning} 从 $source 下载失败，尝试下一个源..."
    done
    
    echo -e "${Error} 所有下载源都失败了"
    return 1
}

# 创建ipset集合
create_ipset() {
    echo -e "${Info} 创建ipset集合..."
    
    # 删除可能存在的旧集合
    ipset destroy "$CHINA_IPSET_NAME" 2>/dev/null
    
    # 创建新的hash:net类型集合
    ipset create "$CHINA_IPSET_NAME" hash:net maxelem 100000
    
    if [[ $? -eq 0 ]]; then
        echo -e "${Success} ipset集合创建成功"
    else
        echo -e "${Error} ipset集合创建失败"
        return 1
    fi
}

# 导入IP段到ipset
import_china_ip() {
    echo -e "${Info} 导入中国IP段到ipset..."
    
    local temp_file="/tmp/china_ip.txt"
    local count=0
    
    if [[ ! -f "$temp_file" ]]; then
        echo -e "${Error} IP列表文件不存在"
        return 1
    fi
    
    # 读取IP段并添加到ipset
    while IFS= read -r line; do
        # 跳过空行和注释行
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # 验证IP段格式
        if [[ "$line" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            ipset add "$CHINA_IPSET_NAME" "$line" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                ((count++))
            fi
        fi
    done < "$temp_file"
    
    echo -e "${Success} 成功导入 $count 个IP段"
    
    # 清理临时文件
    rm -f "$temp_file"
}

# 配置iptables规则
setup_iptables_rules() {
    echo -e "${Info} 配置iptables规则..."
    
    # 方案1: 使用ipset (推荐)
    setup_ipset_rules
    
    echo -e "${Success} iptables规则配置完成"
}

# 使用ipset的iptables规则
setup_ipset_rules() {
    echo -e "${Info} 设置基于ipset的iptables规则..."
    
    # 清理旧规则
    cleanup_old_rules
    
    # 解析端口配置并添加规则
    IFS=',' read -ra port_array <<< "$TARGET_PORT"
    
    for port_spec in "${port_array[@]}"; do
        port_spec=$(echo "$port_spec" | tr -d ' ')
        
        # 单个端口
        if [[ "$port_spec" =~ ^[0-9]+$ ]]; then
            add_iptables_rule_for_port "$port_spec"
        # 端口范围
        elif [[ "$port_spec" =~ ^[0-9]+[:|-][0-9]+$ ]]; then
            add_iptables_rule_for_port_range "$port_spec"
        fi
    done
    
    echo -e "${Success} ipset规则设置完成"
}

# 为单个端口添加规则
add_iptables_rule_for_port() {
    local port="$1"
    
    echo -e "${Info} 添加端口 $port 的阻断规则 [协议: $PROTOCOL]..."
    
    case "$PROTOCOL" in
        "tcp")
            iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_TCP_$port: " --log-level 4
            ;;
        "udp")
            iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_UDP_$port: " --log-level 4
            ;;
        "both")
            iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_TCP_$port: " --log-level 4
            iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_UDP_$port: " --log-level 4
            ;;
    esac
}

# 为端口范围添加规则
add_iptables_rule_for_port_range() {
    local port_range="$1"
    local start_port end_port
    
    if [[ "$port_range" =~ : ]]; then
        start_port=$(echo "$port_range" | cut -d: -f1)
        end_port=$(echo "$port_range" | cut -d: -f2)
    else
        start_port=$(echo "$port_range" | cut -d- -f1)
        end_port=$(echo "$port_range" | cut -d- -f2)
    fi
    
    echo -e "${Info} 添加端口范围 $start_port-$end_port 的阻断规则 [协议: $PROTOCOL]..."
    
    case "$PROTOCOL" in
        "tcp")
            iptables -I INPUT -p tcp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p tcp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_TCP_${start_port}-${end_port}: " --log-level 4
            ;;
        "udp")
            iptables -I INPUT -p udp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p udp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_UDP_${start_port}-${end_port}: " --log-level 4
            ;;
        "both")
            iptables -I INPUT -p tcp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p udp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j DROP
            iptables -I INPUT -p tcp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_TCP_${start_port}-${end_port}: " --log-level 4
            iptables -I INPUT -p udp --dport "$start_port:$end_port" -m set --match-set "$CHINA_IPSET_NAME" src -j LOG --log-prefix "CHINA_IP_BLOCKED_UDP_${start_port}-${end_port}: " --log-level 4
            ;;
    esac
}

# 清理旧规则
cleanup_old_rules() {
    echo -e "${Info} 清理相关的旧规则..."
    
    # 获取所有包含china_ip ipset的规则行号，并删除
    local rule_nums=$(iptables -L INPUT --line-numbers | grep "$CHINA_IPSET_NAME" | awk '{print $1}' | sort -nr)
    
    for num in $rule_nums; do
        iptables -D INPUT "$num" 2>/dev/null
    done
}

# 直接使用iptables规则（备用方案）
setup_direct_iptables_rules() {
    echo -e "${Info} 设置直接iptables规则 [备用方案]..."
    
    # 这种方法会创建大量规则，可能影响性能
    local temp_file="/tmp/china_ip.txt"
    
    if [[ ! -f "$temp_file" ]]; then
        echo -e "${Error} IP列表文件不存在"
        return 1
    fi
    
    # 创建自定义链
    iptables -N CHINA_IP_BLOCK 2>/dev/null
    iptables -F CHINA_IP_BLOCK
    
    # 读取IP段并添加规则
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        if [[ "$line" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            iptables -A CHINA_IP_BLOCK -s "$line" -j DROP
        fi
    done < "$temp_file"
    
    # 解析端口配置并应用自定义链
    IFS=',' read -ra port_array <<< "$TARGET_PORT"
    
    for port_spec in "${port_array[@]}"; do
        port_spec=$(echo "$port_spec" | tr -d ' ')
        
        # 单个端口
        if [[ "$port_spec" =~ ^[0-9]+$ ]]; then
            case "$PROTOCOL" in
                "tcp")
                    iptables -I INPUT -p tcp --dport "$port_spec" -j CHINA_IP_BLOCK
                    ;;
                "udp")
                    iptables -I INPUT -p udp --dport "$port_spec" -j CHINA_IP_BLOCK
                    ;;
                "both")
                    iptables -I INPUT -p tcp --dport "$port_spec" -j CHINA_IP_BLOCK
                    iptables -I INPUT -p udp --dport "$port_spec" -j CHINA_IP_BLOCK
                    ;;
            esac
        # 端口范围
        elif [[ "$port_spec" =~ ^[0-9]+[:|-][0-9]+$ ]]; then
            local start_port end_port
            if [[ "$port_spec" =~ : ]]; then
                start_port=$(echo "$port_spec" | cut -d: -f1)
                end_port=$(echo "$port_spec" | cut -d: -f2)
            else
                start_port=$(echo "$port_spec" | cut -d- -f1)
                end_port=$(echo "$port_spec" | cut -d- -f2)
            fi
            
            case "$PROTOCOL" in
                "tcp")
                    iptables -I INPUT -p tcp --dport "$start_port:$end_port" -j CHINA_IP_BLOCK
                    ;;
                "udp")
                    iptables -I INPUT -p udp --dport "$start_port:$end_port" -j CHINA_IP_BLOCK
                    ;;
                "both")
                    iptables -I INPUT -p tcp --dport "$start_port:$end_port" -j CHINA_IP_BLOCK
                    iptables -I INPUT -p udp --dport "$start_port:$end_port" -j CHINA_IP_BLOCK
                    ;;
            esac
        fi
    done
    
    echo -e "${Success} 直接iptables规则设置完成"
}

# 创建systemd服务实现开机自启
create_systemd_service() {
    echo -e "${Info} 创建systemd服务..."
    
    # 获取协议名称用于服务描述
    local protocol_name
    case "$PROTOCOL" in
        "tcp") protocol_name="TCP" ;;
        "udp") protocol_name="UDP" ;;
        "both") protocol_name="TCP+UDP" ;;
    esac
    
    cat > /etc/systemd/system/china-ip-block.service << 'EOF_SERVICE'
[Unit]
Description=Block China IP Access to Port $TARGET_PORT [$PROTOCOL_NAME]
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/china-ip-block.sh start
ExecStop=/usr/local/bin/china-ip-block.sh stop
TimeoutStartSec=120
User=root

[Install]
WantedBy=multi-user.target
EOF_SERVICE
    
    # 替换变量
    sed -i "s/\$TARGET_PORT/$TARGET_PORT/g" /etc/systemd/system/china-ip-block.service
    sed -i "s/\$PROTOCOL_NAME/$protocol_name/g" /etc/systemd/system/china-ip-block.service
    
    # 复制脚本到系统目录
    cp "$0" /usr/local/bin/china-ip-block.sh 2>/dev/null || {
        echo -e "${Warning} 无法复制脚本到系统目录，尝试使用当前路径"
        sed -i "s|/usr/local/bin/china-ip-block.sh|$(realpath "$0")|g" /etc/systemd/system/china-ip-block.service
    }
    chmod +x /usr/local/bin/china-ip-block.sh 2>/dev/null
    
    # 重新加载并启用服务
    systemctl daemon-reload
    systemctl enable china-ip-block.service
    
    if [[ $? -eq 0 ]]; then
        echo -e "${Success} systemd服务创建并启用成功"
        echo -e "${Info} 服务名称: china-ip-block.service"
        echo -e "${Info} 可使用以下命令管理服务:"
        echo -e "  ${Cyan}systemctl start china-ip-block${Reset}"
        echo -e "  ${Cyan}systemctl stop china-ip-block${Reset}"
        echo -e "  ${Cyan}systemctl status china-ip-block${Reset}"
    else
        echo -e "${Error} systemd服务创建失败"
        return 1
    fi
}

# 保存iptables规则
save_iptables_rules() {
    echo -e "${Info} 保存iptables规则..."
    
    # 尝试多种保存方法，适应不同的Linux发行版
    local saved=false
    
    # 方法1: 使用netfilter-persistent (Debian/Ubuntu)
    if command -v netfilter-persistent &> /dev/null; then
        if netfilter-persistent save; then
            echo -e "${Success} 使用netfilter-persistent保存规则"
            saved=true
        fi
    fi
    
    # 方法2: 使用iptables-persistent (Debian/Ubuntu)
    if [[ "$saved" == false ]] && command -v iptables-save &> /dev/null; then
        if [[ -d /etc/iptables ]]; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null && {
                echo -e "${Success} 规则保存到 /etc/iptables/rules.v4"
                saved=true
            }
        fi
    fi
    
    # 方法3: 使用系统服务 (CentOS/RHEL)
    if [[ "$saved" == false ]] && [[ -f /etc/init.d/iptables ]]; then
        if service iptables save 2>/dev/null; then
            echo -e "${Success} 使用系统服务保存规则"
            saved=true
        fi
    fi
    
    # 方法4: 手动保存到sysconfig (CentOS/RHEL)
    if [[ "$saved" == false ]] && [[ -d /etc/sysconfig ]]; then
        iptables-save > /etc/sysconfig/iptables 2>/dev/null && {
            echo -e "${Success} 规则保存到 /etc/sysconfig/iptables"
            saved=true
        }
    fi
    
    # 方法5: 创建自定义保存位置
    if [[ "$saved" == false ]]; then
        mkdir -p /etc/iptables-backup
        iptables-save > /etc/iptables-backup/rules.v4.$(date +%Y%m%d_%H%M%S) && {
            echo -e "${Success} 规则备份到 /etc/iptables-backup/"
            saved=true
        }
    fi
    
    if [[ "$saved" == false ]]; then
        echo -e "${Warning} 无法自动保存iptables规则，请手动保存"
        echo -e "${Info} 可以使用命令: iptables-save > /path/to/rules.v4"
    fi
}

# 显示当前状态
show_status() {
    echo -e "${Info} 当前阻断状态："
    echo
    
    # 显示配置信息
    if [[ -n "$TARGET_PORT" ]]; then
        echo -e "${Success} 配置端口: ${Green}$TARGET_PORT${Reset}"
    else
        echo -e "${Warning} 未配置端口"
    fi
    
    if [[ -n "$PROTOCOL" ]]; then
        local protocol_name
        case "$PROTOCOL" in
            "tcp") protocol_name="TCP" ;;
            "udp") protocol_name="UDP" ;;
            "both") protocol_name="TCP+UDP" ;;
        esac
        echo -e "${Success} 协议类型: ${Green}$protocol_name${Reset}"
    else
        echo -e "${Warning} 未配置协议"
    fi
    
    # 检查ipset
    if ipset list "$CHINA_IPSET_NAME" &>/dev/null; then
        local ip_count=$(ipset list "$CHINA_IPSET_NAME" | grep -c "^[0-9]")
        echo -e "${Success} ipset集合 '$CHINA_IPSET_NAME' 存在，包含 $ip_count 个IP段"
    else
        echo -e "${Warning} ipset集合 '$CHINA_IPSET_NAME' 不存在"
    fi
    
    # 检查iptables规则
    local rule_count=$(iptables -L INPUT -n | grep -c "$CHINA_IPSET_NAME")
    if [[ $rule_count -gt 0 ]]; then
        echo -e "${Success} 发现 $rule_count 条iptables规则，正在阻断中国IP"
        echo
        echo -e "${Info} 相关规则详情："
        iptables -L INPUT -n --line-numbers | grep "$CHINA_IPSET_NAME" | while read line; do
            echo -e "  ${Cyan}$line${Reset}"
        done
    else
        echo -e "${Warning} 未发现相关iptables规则"
    fi
    
    # 按协议分类显示规则
    if [[ $rule_count -gt 0 ]]; then
        echo
        echo -e "${Info} 规则按协议分类："
        local tcp_rules=$(iptables -L INPUT -n | grep -c "tcp.*$CHINA_IPSET_NAME")
        local udp_rules=$(iptables -L INPUT -n | grep -c "udp.*$CHINA_IPSET_NAME")
        echo -e "  ${Cyan}TCP规则: $tcp_rules 条${Reset}"
        echo -e "  ${Cyan}UDP规则: $udp_rules 条${Reset}"
    fi
    
    # 显示最近的阻断日志
    if [[ -f "$LOG_FILE" ]]; then
        echo
        echo -e "${Info} 最近的阻断记录："
        tail -n 5 "$LOG_FILE" 2>/dev/null || echo "无日志记录"
    fi
    
    # 显示系统日志中的阻断记录
    echo
    echo -e "${Info} 系统日志中的最近阻断记录："
    if command -v journalctl &>/dev/null; then
        journalctl -n 10 --no-pager | grep "CHINA_IP_BLOCKED" | tail -5 2>/dev/null || echo "无阻断记录"
    else
        tail -n 50 /var/log/kern.log 2>/dev/null | grep "CHINA_IP_BLOCKED" | tail -5 || echo "无阻断记录"
    fi
}

# 清理规则
cleanup_rules() {
    echo -e "${Info} 清理阻断规则..."
    
    # 删除包含china_ip ipset的所有iptables规则
    local rule_nums=$(iptables -L INPUT --line-numbers | grep "$CHINA_IPSET_NAME" | awk '{print $1}' | sort -nr)
    
    for num in $rule_nums; do
        iptables -D INPUT "$num" 2>/dev/null
        echo -e "${Info} 删除规则行 $num"
    done
    
    # 删除ipset集合
    ipset destroy "$CHINA_IPSET_NAME" 2>/dev/null && echo -e "${Success} 删除ipset集合"
    
    # 删除自定义链（如果使用直接规则方案）
    # 首先删除引用自定义链的规则
    local chain_rules=$(iptables -L INPUT --line-numbers | grep "CHINA_IP_BLOCK" | awk '{print $1}' | sort -nr)
    for num in $chain_rules; do
        iptables -D INPUT "$num" 2>/dev/null
    done
    
    # 清空并删除自定义链
    iptables -F CHINA_IP_BLOCK 2>/dev/null
    iptables -X CHINA_IP_BLOCK 2>/dev/null
    
    echo -e "${Success} 规则清理完成"
}

# 测试端口连通性
test_port_connectivity() {
    if [[ -z "$TARGET_PORT" ]]; then
        echo -e "${Error} 请先配置端口"
        return 1
    fi
    
    echo -e "${Info} 测试端口连通性..."
    echo -e "${Info} 当前协议配置: ${Green}$PROTOCOL${Reset}"
    echo
    
    # 解析端口配置
    IFS=',' read -ra port_array <<< "$TARGET_PORT"
    
    for port_spec in "${port_array[@]}"; do
        port_spec=$(echo "$port_spec" | tr -d ' ')
        
        # 单个端口测试
        if [[ "$port_spec" =~ ^[0-9]+$ ]]; then
            test_single_port "$port_spec"
        # 端口范围测试（只测试起始和结束端口）
        elif [[ "$port_spec" =~ ^[0-9]+[:|-][0-9]+$ ]]; then
            local start_port end_port
            if [[ "$port_spec" =~ : ]]; then
                start_port=$(echo "$port_spec" | cut -d: -f1)
                end_port=$(echo "$port_spec" | cut -d: -f2)
            else
                start_port=$(echo "$port_spec" | cut -d- -f1)
                end_port=$(echo "$port_spec" | cut -d- -f2)
            fi
            
            echo -e "${Info} 测试端口范围 $start_port-$end_port："
            test_single_port "$start_port"
            if [[ $start_port -ne $end_port ]]; then
                test_single_port "$end_port"
            fi
        fi
    done
}

# 测试单个端口
test_single_port() {
    local port="$1"
    
    echo -e "${Info} 测试端口 $port..."
    
    # 检查端口是否正在监听
    case "$PROTOCOL" in
        "tcp")
            if ss -tln | grep -q ":$port "; then
                echo -e "${Success} TCP端口 $port 正在监听"
                local process=$(ss -tlnp | grep ":$port " | head -1)
                if [[ -n "$process" ]]; then
                    echo -e "${Info} 进程信息: $process"
                fi
            else
                echo -e "${Warning} TCP端口 $port 未在监听"
            fi
            ;;
        "udp")
            if ss -uln | grep -q ":$port "; then
                echo -e "${Success} UDP端口 $port 正在监听"
                local process=$(ss -ulnp | grep ":$port " | head -1)
                if [[ -n "$process" ]]; then
                    echo -e "${Info} 进程信息: $process"
                fi
            else
                echo -e "${Warning} UDP端口 $port 未在监听"
            fi
            ;;
        "both")
            local tcp_listening=false
            local udp_listening=false
            
            if ss -tln | grep -q ":$port "; then
                echo -e "${Success} TCP端口 $port 正在监听"
                local tcp_process=$(ss -tlnp | grep ":$port " | head -1)
                if [[ -n "$tcp_process" ]]; then
                    echo -e "${Info} TCP进程信息: $tcp_process"
                fi
                tcp_listening=true
            else
                echo -e "${Warning} TCP端口 $port 未在监听"
            fi
            
            if ss -uln | grep -q ":$port "; then
                echo -e "${Success} UDP端口 $port 正在监听"
                local udp_process=$(ss -ulnp | grep ":$port " | head -1)
                if [[ -n "$udp_process" ]]; then
                    echo -e "${Info} UDP进程信息: $udp_process"
                fi
                udp_listening=true
            else
                echo -e "${Warning} UDP端口 $port 未在监听"
            fi
            ;;
    esac
    
    # 测试本地连接（非阻断测试）
    case "$PROTOCOL" in
        "tcp"|"both")
            if command -v nc &>/dev/null; then
                if timeout 3 nc -z localhost "$port" 2>/dev/null; then
                    echo -e "${Success} 本地TCP连接端口 $port 成功"
                else
                    echo -e "${Warning} 本地TCP连接端口 $port 失败"
                fi
            elif command -v telnet &>/dev/null; then
                if timeout 3 bash -c "echo '' | telnet localhost $port" &>/dev/null; then
                    echo -e "${Success} 本地TCP连接端口 $port 成功"
                else
                    echo -e "${Warning} 本地TCP连接端口 $port 失败"
                fi
            fi
            ;;
    esac
    
    case "$PROTOCOL" in
        "udp"|"both")
            if command -v nc &>/dev/null; then
                if timeout 3 nc -u -z localhost "$port" 2>/dev/null; then
                    echo -e "${Success} 本地UDP连接端口 $port 成功"
                else
                    echo -e "${Warning} 本地UDP连接端口 $port 失败或无响应"
                fi
            fi
            ;;
    esac
    
    echo
}

# 显示菜单
show_menu() {
    echo
    echo -e "${Blue}=== 中国IP端口阻断工具 ===${Reset}"
    
    if [[ -n "$TARGET_PORT" ]]; then
        echo -e "${Blue}当前配置端口: ${Green}$TARGET_PORT${Reset}"
    else
        echo -e "${Blue}当前配置端口: ${Red}未配置${Reset}"
    fi
    
    if [[ -n "$PROTOCOL" ]]; then
        local protocol_name
        case "$PROTOCOL" in
            "tcp") protocol_name="TCP" ;;
            "udp") protocol_name="UDP" ;;
            "both") protocol_name="TCP+UDP" ;;
        esac
        echo -e "${Blue}当前协议类型: ${Green}$protocol_name${Reset}"
    else
        echo -e "${Blue}当前协议类型: ${Red}未配置${Reset}"
    fi
    
    echo
    echo -e "${Green}1.${Reset} 配置端口和协议"
    echo -e "${Green}2.${Reset} 启用阻断 [推荐ipset方案]"
    echo -e "${Green}3.${Reset} 启用阻断 [直接iptables方案]"
    echo -e "${Yellow}4.${Reset} 查看当前状态"
    echo -e "${Yellow}5.${Reset} 更新IP列表"
    echo -e "${Cyan}6.${Reset} 创建开机自启服务"
    echo -e "${Magenta}7.${Reset} 测试端口连通性"
    echo -e "${Red}8.${Reset} 清理所有规则"
    echo -e "${Red}0.${Reset} 退出"
    echo
}

# 主函数
main() {
    check_root
    load_config
    
    echo -e "${Blue}"
    echo "=================================================="
    echo "         Linux 中国IP端口阻断工具"
    if [[ -n "$TARGET_PORT" ]]; then
        echo "           目标端口: $TARGET_PORT"
    else
        echo "           目标端口: 未配置"
    fi
    if [[ -n "$PROTOCOL" ]]; then
        local protocol_name
        case "$PROTOCOL" in
            "tcp") protocol_name="TCP" ;;
            "udp") protocol_name="UDP" ;;
            "both") protocol_name="TCP+UDP" ;;
        esac
        echo "           协议类型: $protocol_name"
    else
        echo "           协议类型: 未配置"
    fi
    echo "=================================================="
    echo -e "${Reset}"
    
    case "${1:-}" in
        "start")
            if [[ -z "$TARGET_PORT" || -z "$PROTOCOL" ]]; then
                echo -e "${Error} 端口或协议未配置，请先运行脚本配置"
                exit 1
            fi
            check_dependencies
            if download_china_ip; then
                create_ipset
                import_china_ip
                setup_iptables_rules
                save_iptables_rules
                echo -e "${Success} 中国IP阻断已启用"
                echo -e "${Success} 端口: $TARGET_PORT，协议: $PROTOCOL"
            else
                echo -e "${Error} 启用失败"
                exit 1
            fi
            ;;
        "stop")
            cleanup_rules
            echo -e "${Success} 中国IP阻断已停用"
            ;;
        "status")
            show_status
            ;;
        *)
            while true; do
                show_menu
                read -p "请选择操作 [0-8]: " choice
                
                case $choice in
                    1)
                        if configure_port_and_protocol; then
                            echo -e "${Success} 端口和协议配置完成"
                        fi
                        ;;
                    2)
                        if [[ -z "$TARGET_PORT" || -z "$PROTOCOL" ]]; then
                            echo -e "${Error} 请先配置端口和协议"
                        else
                            check_dependencies
                            if download_china_ip; then
                                create_ipset
                                import_china_ip
                                setup_iptables_rules
                                save_iptables_rules
                                echo -e "${Success} ipset方案启用成功！"
                                echo -e "${Success} 端口: $TARGET_PORT，协议: $PROTOCOL"
                            fi
                        fi
                        ;;
                    3)
                        if [[ -z "$TARGET_PORT" || -z "$PROTOCOL" ]]; then
                            echo -e "${Error} 请先配置端口和协议"
                        else
                            check_dependencies
                            if download_china_ip; then
                                iptables -N CHINA_IP_BLOCK 2>/dev/null
                                setup_direct_iptables_rules
                                save_iptables_rules
                                echo -e "${Success} 直接iptables方案启用成功！"
                                echo -e "${Success} 端口: $TARGET_PORT，协议: $PROTOCOL"
                            fi
                        fi
                        ;;
                    4)
                        show_status
                        ;;
                    5)
                        if download_china_ip; then
                            if ipset list "$CHINA_IPSET_NAME" &>/dev/null; then
                                ipset flush "$CHINA_IPSET_NAME"
                                import_china_ip
                                echo -e "${Success} IP列表更新完成！"
                            else
                                echo -e "${Warning} 请先启用阻断功能"
                            fi
                        fi
                        ;;
                    6)
                        if [[ -n "$TARGET_PORT" && -n "$PROTOCOL" ]]; then
                            create_systemd_service
                        else
                            echo -e "${Error} 请先配置端口和协议"
                        fi
                        ;;
                    7)
                        test_port_connectivity
                        ;;
                    8)
                        echo -e "${Warning} 即将清理所有配置，是否确认？ [y/N]"
                        read -p "确认清理: " confirm_clean
                        case $confirm_clean in
                            [Yy]|[Yy][Ee][Ss])
                                cleanup_rules
                                systemctl disable china-ip-block.service 2>/dev/null
                                systemctl stop china-ip-block.service 2>/dev/null
                                rm -f /etc/systemd/system/china-ip-block.service
                                rm -f /usr/local/bin/china-ip-block.sh
                                rm -f "$CONFIG_FILE"
                                systemctl daemon-reload
                                echo -e "${Success} 所有规则、配置和服务已清理！"
                                ;;
                            *)
                                echo -e "${Info} 取消清理操作"
                                ;;
                        esac
                        ;;
                    0)
                        echo -e "${Info} 退出脚本"
                        exit 0
                        ;;
                    *)
                        echo -e "${Error} 无效选择，请输入 0-8"
                        ;;
                esac
                
                echo
                read -p "按回车键继续..."
            done
            ;;
    esac
}

# 脚本入口
main "$@"

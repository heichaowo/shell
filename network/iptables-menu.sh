#!/bin/bash

while true; do
    clear
    echo "选择要执行的操作:"
    echo "1. 查看防火墙规则"
    echo "2. 允许入站连接"
    echo "3. 允许出站连接"
    echo "4. 禁止入站连接"
    echo "5. 禁止出站连接"
    echo "6. 允许特定端口和协议"
    echo "7. 清除所有规则"
    echo "8. 退出"

    read -p "请输入操作的数字: " choice

    case $choice in
        1)
            sudo iptables -L -n -v
            read -p "按 Enter 键继续..."
            ;;
        2)
            sudo iptables -P INPUT ACCEPT
            echo "已允许所有入站连接"
            read -p "按 Enter 键继续..."
            ;;
        3)
            sudo iptables -P OUTPUT ACCEPT
            echo "已允许所有出站连接"
            read -p "按 Enter 键继续..."
            ;;
        4)
            sudo iptables -P INPUT DROP
            echo "已禁止所有入站连接"
            read -p "按 Enter 键继续..."
            ;;
        5)
            sudo iptables -P OUTPUT DROP
            echo "已禁止所有出站连接"
            read -p "按 Enter 键继续..."
            ;;
        6)
            read -p "请输入要允许的端口（例如：80）: " port
            read -p "请输入协议（tcp/udp）: " protocol
            sudo iptables -A INPUT -p $protocol --dport $port -j ACCEPT
            echo "已允许端口 $port 上的 $protocol 连接"
            read -p "按 Enter 键继续..."
            ;;
        7)
            sudo iptables -F
            echo "已清除所有防火墙规则"
            read -p "按 Enter 键继续..."
            ;;
        8)
            echo "退出脚本"
            exit
            ;;
        *)
            echo "无效的选项，请重新输入"
            read -p "按 Enter 键继续..."
            ;;
    esac
done

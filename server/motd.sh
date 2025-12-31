#!/bin/bash
set -e

# 配置变量 - 可根据需求修改
SERVER_NAME="${1:-MoeNet}"  # 第一个参数作为服务器名,默认为 MyServer
BANNER_COLOR="\033[33m"       # 横幅主色(黄色)
ACCENT_COLOR="\033[31m"       # 强调色(红色)
RESET_COLOR="\033[0m"

echo "======================================"
echo "配置服务器启动界面: $SERVER_NAME"
echo "======================================"
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 1. 安装依赖
echo "[1/4] 检查并安装依赖..."
if ! command -v fastfetch &> /dev/null; then
    echo "正在安装 fastfetch..."
    apt update
    apt install -y fastfetch
else
    echo "✓ fastfetch 已安装"
fi

if ! command -v figlet &> /dev/null; then
    echo "正在安装 figlet (用于生成 ASCII 艺术字)..."
    apt install -y figlet
else
    echo "✓ figlet 已安装"
fi

# 2. 配置 cloud.sh
echo "[2/4] 配置系统环境..."
cat > /etc/profile.d/cloud.sh << 'EOF'
HISTSIZE=10000
PS1='${debian_chroot:+()}\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]\h \[\033[01;33m\]\w \[\033[01;35m\]$ \[\033[00m\]'
HISTTIMEFORMAT="%F %T $(whoami) "
alias l='ls -AFhlt --color=no'
alias lh='l | head'
alias ll='ls -l --color=no'
alias ls='ls --color=no'
alias vi=vim
GREP_OPTIONS="--color=auto"
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi
EOF
chmod 644 /etc/profile.d/cloud.sh

# 3. 生成 ASCII 横幅
echo "[3/4] 生成 ASCII 横幅..."
ASCII_BANNER=$(figlet -f standard "$SERVER_NAME" 2>/dev/null || echo "$SERVER_NAME")

# 4. 配置 .profile
echo "[4/4] 配置登录脚本..."
cat > /root/.profile << EOF
# ~/.profile: executed by Bourne-compatible login shells.
if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
source /etc/profile.d/cloud.sh
fastfetch
echo -e "
$ASCII_BANNER
--------------
${BANNER_COLOR}Thanks for using $SERVER_NAME${RESET_COLOR} ${ACCENT_COLOR}(built-in BBR and TCP Optimization)${RESET_COLOR}
"
EOF
chmod 644 /root/.profile

# 同样配置到 /etc/skel
cp /root/.profile /etc/skel/.profile

echo ""
echo "======================================"
echo "✓ 配置完成!"
echo "======================================"
echo ""
echo "效果预览:"
echo "------------------------------------"
source /root/.profile
echo "------------------------------------"
echo ""
echo "重新登录查看完整效果"
echo ""
echo "自定义提示:"
echo "1. 修改服务器名: $0 \"新名称\""
echo "2. 修改横幅颜色: 编辑 /root/.profile"
echo "3. 修改提示符: 编辑 /etc/profile.d/cloud.sh"
echo ""

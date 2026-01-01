#!/bin/bash
set -e

# 配置变量 - 可根据需求修改
SERVER_NAME="${1:-MoeNet}"  # 第一个参数作为服务器名,默认为 MoeNet
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

# 检测系统版本
DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1 2>/dev/null || echo "0")
echo "检测到 Debian 版本: $DEBIAN_VERSION"
echo ""

# 安装 fastfetch 函数
install_fastfetch() {
    echo "正在安装 fastfetch..."
    
    # 检测架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            FASTFETCH_ARCH="amd64"
            ;;
        aarch64|arm64)
            FASTFETCH_ARCH="aarch64"
            ;;
        armv7l)
            FASTFETCH_ARCH="armv7"
            ;;
        *)
            echo "⚠ 不支持的架构: $ARCH,将使用 neofetch"
            return 1
            ;;
    esac
    
    # 方法1: 尝试从 fastfetch 官方仓库下载 deb 包
    echo "尝试方法1: 从官方仓库下载 deb 包..."
    FASTFETCH_VERSION="2.40.4"
    DEB_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/fastfetch-linux-${FASTFETCH_ARCH}.deb"
    
    cd /tmp
    if wget -q --timeout=10 "$DEB_URL" -O fastfetch.deb 2>/dev/null; then
        if dpkg -i fastfetch.deb 2>/dev/null; then
            echo "✓ 方法1成功: deb 包安装完成"
            rm -f fastfetch.deb
            return 0
        fi
        rm -f fastfetch.deb
    fi
    
    # 方法2: 下载预编译二进制文件
    echo "尝试方法2: 下载预编译二进制文件..."
    BINARY_URL="https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/fastfetch-linux-${FASTFETCH_ARCH}.tar.gz"
    
    if wget -q --timeout=10 "$BINARY_URL" -O fastfetch.tar.gz 2>/dev/null; then
        tar -xzf fastfetch.tar.gz 2>/dev/null
        if [ -f "usr/bin/fastfetch" ]; then
            cp usr/bin/fastfetch /usr/local/bin/fastfetch
            chmod +x /usr/local/bin/fastfetch
            echo "✓ 方法2成功: 二进制文件安装完成"
            rm -rf fastfetch.tar.gz usr
            return 0
        fi
        rm -rf fastfetch.tar.gz usr
    fi
    
    # 方法3: 使用国内镜像源 (ghproxy)
    echo "尝试方法3: 使用镜像加速下载..."
    MIRROR_URL="https://ghproxy.com/${DEB_URL}"
    
    if wget -q --timeout=10 "$MIRROR_URL" -O fastfetch.deb 2>/dev/null; then
        if dpkg -i fastfetch.deb 2>/dev/null; then
            echo "✓ 方法3成功: 镜像源安装完成"
            rm -f fastfetch.deb
            return 0
        fi
        rm -f fastfetch.deb
    fi
    
    echo "⚠ 所有方法均失败,将使用 neofetch 替代"
    return 1
}

# 1. 安装依赖
echo "[1/4] 检查并安装依赖..."

# 更新包列表
apt update -qq

# 安装 fastfetch
if ! command -v fastfetch &> /dev/null; then
    # 尝试从官方源安装
    if apt-cache show fastfetch &> /dev/null 2>&1; then
        echo "从官方源安装 fastfetch..."
        apt install -y fastfetch
        FETCH_CMD="fastfetch"
    else
        # 尝试手动安装
        if install_fastfetch; then
            FETCH_CMD="fastfetch"
        else
            # 降级使用 neofetch
            echo "安装 neofetch 作为替代..."
            apt install -y neofetch
            FETCH_CMD="neofetch"
        fi
    fi
else
    echo "✓ fastfetch 已安装"
    FETCH_CMD="fastfetch"
fi

# 确认安装结果
if command -v fastfetch &> /dev/null; then
    FETCH_CMD="fastfetch"
    echo "✓ 将使用 fastfetch"
elif command -v neofetch &> /dev/null; then
    FETCH_CMD="neofetch"
    echo "✓ 将使用 neofetch"
else
    echo "✗ 系统信息工具安装失败,将跳过此功能"
    FETCH_CMD="# fastfetch"
fi

# 安装 figlet
if ! command -v figlet &> /dev/null; then
    echo "正在安装 figlet..."
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
$FETCH_CMD
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
echo "安装信息:"
echo "- Debian 版本: $DEBIAN_VERSION"
echo "- 系统信息工具: $FETCH_CMD"
echo "- 服务器名称: $SERVER_NAME"
echo ""
echo "效果预览:"
echo "------------------------------------"
source /root/.profile 2>/dev/null || echo "请重新登录查看完整效果"
echo "------------------------------------"
echo ""
echo "重新登录查看完整效果"
echo ""
echo "自定义提示:"
echo "1. 修改服务器名: $0 \"新名称\""
echo "2. 修改横幅颜色: 编辑 /root/.profile"
echo "3. 修改提示符: 编辑 /etc/profile.d/cloud.sh"
echo ""

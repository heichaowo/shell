# shell

个人运维脚本集，自用为主，部分基于开源项目改造。**使用前请仔细阅读脚本注释**，注意硬编码配置（端口号、域名、版本号等）。

---

## 目录结构

```
shell/
├── network/    # 网络与防火墙
├── system/     # 系统优化与内核
└── service/    # 服务安装与维护
```

---

## network/ — 网络与防火墙

| 脚本 | 功能 |
|------|------|
| `firewall.sh` | iptables 防火墙基础规则，适用于 Hysteria2/sing-box 节点，开放常用端口，默认 DROP |
| `adapt-wireguard.sh` | 追加 WireGuard 51820/51821 端口规则（需先跑 firewall.sh） |
| `adapt-udp-nat.sh` | UDP 20000–50000 端口段 NAT 转发到 443（Hysteria2 多端口场景） |
| `adguardhome.sh` | AdGuardHome 所需端口规则（DNS/DoT/DoH/管理面板） |
| `rustdesk.sh` | RustDesk 自建中继所需端口规则 |
| `iptables-menu.sh` | 交互式 iptables 管理菜单，支持查看/允许/禁止规则 |
| `iptables-fw.sh` | iptables 端口转发脚本，带交互菜单，支持 TCP/UDP |
| `block-china-ip.sh` | 从 APNIC 拉取中国 IP 段并用 iptables 封锁 |
| `fail2ban-udp.sh` | 安装 fail2ban 并配置 UDP 滥用检测规则 |
| `dns.sh` | 安装 cloudflared 并配置为 DoH 上游 DNS |

```bash
BASE=https://raw.githubusercontent.com/heichaowo/shell/main/network

bash <(wget -qO- $BASE/firewall.sh)
bash <(wget -qO- $BASE/adapt-wireguard.sh)
bash <(wget -qO- $BASE/adapt-udp-nat.sh)
bash <(wget -qO- $BASE/adguardhome.sh)
bash <(wget -qO- $BASE/rustdesk.sh)
bash <(wget -qO- $BASE/iptables-menu.sh)
bash <(wget -qO- $BASE/iptables-fw.sh)
bash <(wget -qO- $BASE/block-china-ip.sh)
bash <(wget -qO- $BASE/fail2ban-udp.sh)
bash <(wget -qO- $BASE/dns.sh)
```

---

## system/ — 系统优化与内核

| 脚本 | 功能 |
|------|------|
| `bbr3.sh` | 编译安装支持 BBR3 的内核，带颜色提示，耗时较长 |
| `kernel.sh` | 内核升级脚本，支持 Debian/Ubuntu |
| `ram-optimize.sh` | 调整 vm.swappiness、vfs_cache_pressure 等内存参数 |
| `swap.sh` | 参数化创建 Swap 文件，用法：`./swap.sh 2G` |
| `fucksnap.sh` | Ubuntu 彻底移除 snapd 及无用系统服务 |
| `motd.sh` | 自定义服务器登录欢迎界面（MOTD），支持传参服务器名，默认 MoeNet |

```bash
BASE=https://raw.githubusercontent.com/heichaowo/shell/main/system

bash <(wget -qO- $BASE/bbr3.sh)
bash <(wget -qO- $BASE/kernel.sh)
bash <(wget -qO- $BASE/ram-optimize.sh)
wget -qO swap.sh $BASE/swap.sh && bash swap.sh 2G
bash <(wget -qO- $BASE/fucksnap.sh)
bash <(wget -qO- $BASE/motd.sh) MyServerName
```

---

## service/ — 服务安装与维护

| 脚本 | 功能 |
|------|------|
| `nginx-installer.sh` | 从 Nginx 官方源完整安装，需 root |
| `nginx-stable.sh` | 快速安装 Nginx stable 版（极简版） |
| `oh-my-acme.sh` | acme.sh 多域名 SSL 证书申请，支持主域名 + SAN |
| `go-installer.sh` | Go 1.24.5 环境安装 |
| `derper-build.sh` | 构建 Tailscale DERP 中继节点（依赖 Go） |
| `update-xray.sh` | 自动获取 Xray-core 最新版并更新 |
| `update-paper.sh` | 自动从 PaperMC API 获取最新构建并下载（Minecraft 1.21.1） |
| `stop-goedge-update.sh` | 通过 hosts 文件屏蔽 GoEdge 自动更新域名 |

```bash
BASE=https://raw.githubusercontent.com/heichaowo/shell/main/service

bash <(wget -qO- $BASE/nginx-installer.sh)
bash <(wget -qO- $BASE/nginx-stable.sh)
bash <(wget -qO- $BASE/oh-my-acme.sh) example.com www.example.com
bash <(wget -qO- $BASE/go-installer.sh)
bash <(wget -qO- $BASE/derper-build.sh)
bash <(wget -qO- $BASE/update-xray.sh)
bash <(wget -qO- $BASE/update-paper.sh)
bash <(wget -qO- $BASE/stop-goedge-update.sh)
```

---

## 注意事项

- 脚本均以 **root** 权限运行为前提，部分脚本有 root 检查
- 部分脚本含**硬编码配置**（端口号、域名、版本号），使用前请阅读注释并按需修改
- `firewall.sh` 系列会直接操作 iptables，执行前确认不会断开当前 SSH 连接
- `bbr3.sh` 需要编译内核，执行后需重启
- `block-china-ip.sh` 规则量大（1000+ 条），低配机器慎用
- `oh-my-acme.sh` 需提前配置好 DNS 解析
- 所有脚本均基于 Debian/Ubuntu，其他发行版未经测试

> 自用脚本，按需取用，后果自负。

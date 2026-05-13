#!/usr/bin/env bash
#启用BBR+fq_codel
  remove_bbr_lotserver
  echo "net.core.default_qdisc=fq_codel" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system
  echo -e "${Info}BBR+FQ_CODEL修改成功，重启生效！"

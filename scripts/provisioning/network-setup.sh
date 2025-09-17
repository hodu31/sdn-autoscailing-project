#!/bin/bash

# 기본 네트워크 설정 스크립트
# VM 초기 프로비저닝시 실행됩니다

set -e

echo "=== 네트워크 인터페이스 목록 ==="
ip link show
nmcli con show

echo "=== 방화벽 설정 ==="
systemctl start firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --zone=trusted --add-source=192.168.100.0/24
firewall-cmd --reload

echo "=== SELinux 설정 ==="
setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

echo "=== DNS 설정 ==="
echo "nameserver 168.126.63.1" >> /etc/resolv.conf

echo "=== 필수 패키지 설치 ==="
dnf install -y python3 python3-pip net-tools curl wget vim

echo "=== Kubernetes 요구사항 설정 ==="
# swap 비활성화
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 커널 모듈 로드
modprobe br_netfilter
echo 'br_netfilter' > /etc/modules-load.d/k8s.conf

# 커널 파라미터 설정
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "=== 기본 네트워크 설정 완료 ==="
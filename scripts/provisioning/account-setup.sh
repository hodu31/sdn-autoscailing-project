#!/bin/bash

# 계정 및 SSH 설정 스크립트
# VM 계정 설정을 담당합니다

set -e

# 환경변수에서 비밀번호 읽기
ROOT_PASSWORD=${ROOT_PASSWORD:-"defaultpass123"}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"admin123"}
VAGRANT_PASSWORD=${VAGRANT_PASSWORD:-"vagrant"}

echo "=== SSH 서버 설치 ==="
# SSH 서버가 설치되어 있지 않은 경우 설치
if ! rpm -qa | grep -q openssh-server; then
    echo "openssh-server 설치 중..."
    yum install -y openssh-server openssh-clients
fi

echo "=== 계정 비밀번호 설정 ==="
# Root 계정 비밀번호 설정
echo "root:${ROOT_PASSWORD}" | chpasswd

# Vagrant 계정 비밀번호 변경
echo "vagrant:${VAGRANT_PASSWORD}" | chpasswd

# 관리자 계정 생성
useradd -m -s /bin/bash admin 2>/dev/null || true
echo "admin:${ADMIN_PASSWORD}" | chpasswd
usermod -aG wheel admin

echo "=== sudoers 설정 ==="
echo "vagrant ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vagrant
echo "admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin
chmod 440 /etc/sudoers.d/vagrant
chmod 440 /etc/sudoers.d/admin

echo "=== SSH 설정 ==="
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# SSH 키 설정
mkdir -p /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
if [ -f /home/vagrant/.ssh/authorized_keys ]; then
    chmod 600 /home/vagrant/.ssh/authorized_keys
fi
chown -R vagrant:vagrant /home/vagrant/.ssh

# SSH 서비스 재시작
systemctl restart sshd
systemctl enable sshd

echo "=== 계정 및 SSH 설정 완료 ==="
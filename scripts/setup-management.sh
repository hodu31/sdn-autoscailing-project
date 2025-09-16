#!/bin/bash
# setup-management.sh - Management Server 설정 스크립트

echo "=== Management Server 설정 시작 ==="

# 시스템 업데이트 건너뛰기 (시간 절약)
echo "기본 패키지만 설치합니다..."

# 필수 패키지 설치
echo "기본 패키지 설치 중..."
dnf install -y epel-release
dnf install -y wget curl vim git python3 python3-pip

# Ansible 설치
echo "Ansible 설치 중..."
dnf install -y ansible-core
pip3 install ansible docker-py kubernetes

# 방화벽 설정
echo "방화벽 설정 중..."
firewall-cmd --permanent --add-port=9090/tcp  # Prometheus
firewall-cmd --permanent --add-port=3000/tcp  # Grafana
firewall-cmd --permanent --add-port=22/tcp    # SSH
firewall-cmd --reload

# SSH 키 생성 (다른 VM들과 통신용)
echo "SSH 키 생성 중..."
sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa

# Ansible 인벤토리 디렉터리 생성
mkdir -p /home/vagrant/ansible
chown -R vagrant:vagrant /home/vagrant/ansible

echo "=== Management Server 설정 완료 ==="
echo "Prometheus: http://192.168.100.10:9090"
echo "Grafana: http://192.168.100.10:3000 (admin/admin)"
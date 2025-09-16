#!/bin/bash
# setup-management.sh - Management Server 최소 설정 (Ansible만)

echo "=== Management Server 설정 시작 (Ansible Only) ==="

# 기본 패키지 설치
echo "기본 패키지 설치 중..."
dnf install -y epel-release wget curl vim git python3 python3-pip sshpass

# Ansible 설치
echo "Ansible 설치 중..."
dnf install -y ansible-core
pip3 install ansible docker-py kubernetes

# SSH 키 생성 및 배포
echo "SSH 키 생성 중..."
sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa

# 다른 VM들에 SSH 키 배포 (Root 계정으로)
echo "SSH 키 배포 중..."
sudo -u vagrant sshpass -p 'dksgo1234' ssh-copy-id -o StrictHostKeyChecking=no root@192.168.100.20
sudo -u vagrant sshpass -p 'dksgo1234' ssh-copy-id -o StrictHostKeyChecking=no root@192.168.100.30

# Ansible 설정 복사
echo "Ansible 설정 복사 중..."
cp -r /vagrant/ansible /home/vagrant/
chown -R vagrant:vagrant /home/vagrant/ansible

# 기본 방화벽 설정
echo "방화벽 설정 중..."
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --reload

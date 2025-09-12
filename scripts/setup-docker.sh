#!/bin/bash
# setup-docker.sh - Application Server 설정 스크립트

echo "=== Application Server 설정 시작 ==="

# 시스템 업데이트 건너뛰기 (시간 절약)
echo "기본 패키지만 설치합니다..."

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# vagrant 사용자를 docker 그룹에 추가
usermod -aG docker vagrant

# Docker 서비스 시작
systemctl enable --now docker

# Node Exporter 설치
docker run -d \
  --name=node-exporter \
  --restart=always \
  -p 9100:9100 \
  prom/node-exporter:latest

# 기본 웹서버 컨테이너 시작
docker run -d \
  --name=web-server-1 \
  --restart=always \
  -p 80:80 \
  nginx:alpine

# 방화벽 설정
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=9100/tcp
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --reload

echo "=== Application Server 설정 완료 ==="
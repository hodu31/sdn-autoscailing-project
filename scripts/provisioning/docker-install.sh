#!/bin/bash

# Docker 설치 스크립트
# Docker 및 관련 도구를 설치합니다

set -e

echo "=== Docker 저장소 추가 ==="
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

echo "=== Docker 패키지 설치 ==="
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== Docker 서비스 시작 ==="
systemctl enable docker
systemctl start docker

echo "=== 사용자를 docker 그룹에 추가 ==="
usermod -aG docker vagrant
usermod -aG docker admin

echo "=== Docker 설정 확인 ==="
docker --version

echo "=== Docker 설치 완료 ==="
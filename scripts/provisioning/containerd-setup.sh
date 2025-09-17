#!/bin/bash

# containerd 설정 스크립트
# Kubernetes용 containerd 설정을 담당합니다

set -e

echo "=== containerd 설정 ==="
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

echo "=== SystemdCgroup 설정 ==="
# SystemdCgroup = true 설정 (Kubernetes 요구사항)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

echo "=== containerd 재시작 ==="
systemctl restart containerd
systemctl enable containerd

echo "=== containerd 상태 확인 ==="
systemctl status containerd --no-pager

echo "=== containerd 설정 완료 ==="
#!/bin/bash

# Kubernetes 패키지 설치 스크립트
# kubeadm, kubelet, kubectl을 설치합니다

set -e

echo "=== Kubernetes 저장소 추가 ==="
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# 필수 패키지 설치
dnf install -y python3 python3-pip vim curl git

echo "=== Kubernetes 패키지 설치 ==="
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

echo "=== kubelet 서비스 활성화 ==="
systemctl enable kubelet

echo "=== 설치 확인 ==="
kubeadm version
kubelet --version
kubectl version --client

echo "=== Kubernetes 패키지 설치 완료 ==="
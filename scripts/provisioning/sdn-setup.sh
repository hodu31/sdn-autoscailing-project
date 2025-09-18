#!/bin/bash

# SDN Controller 설정 스크립트
# Ryu SDN Controller와 OpenVSwitch를 설정합니다

set -e

# 환경변수
SDN_IP=${SDN_IP:-"192.168.100.20"}
MGMT_IP=${MGMT_IP:-"192.168.100.10"}
K8S_MASTER_IP=${K8S_MASTER_IP:-"192.168.100.30"}
NETWORK_SUBNET=${NETWORK_SUBNET:-"192.168.100"}
K8S_WORKER_START_IP=${K8S_WORKER_START_IP:-"31"}
K8S_WORKER_COUNT=${K8S_WORKER_COUNT:-"2"}


echo "=== SDN 관련 패키지 설치 ==="
# 개발 도구 설치
dnf install -y python3-devel gcc

# OpenVSwitch 설치
dnf install -y openvswitch

# Ryu Controller 설치
pip3 install ryu eventlet

echo "=== Open vSwitch 서비스 시작 ==="
systemctl enable openvswitch
systemctl start openvswitch

# OVS 상태 확인
ovs-vsctl show

echo "=== SDN Controller 방화벽 설정 ==="
firewall-cmd --permanent --add-port=6633/tcp  # OpenFlow
firewall-cmd --permanent --add-port=6653/tcp  # OpenFlow over TLS
firewall-cmd --reload

echo "=== Hosts 파일 업데이트 ==="
cat <<EOF >> /etc/hosts
${MGMT_IP} mgmt-server
${SDN_IP} sdn-controller
${K8S_MASTER_IP} k8s-master
EOF

# 워커 노드들도 hosts에 추가
for i in $(seq 1 ${K8S_WORKER_COUNT}); do
    worker_ip=$((${K8S_WORKER_START_IP} + i - 1))
    echo "${NETWORK_SUBNET}.${worker_ip} k8s-worker${i}" >> /etc/hosts
done

echo "=== SDN Controller 설정 완료 ==="
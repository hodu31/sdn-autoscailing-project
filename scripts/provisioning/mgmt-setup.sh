#!/bin/bash

# Management Server 설정 스크립트
# 관리 도구들과 모니터링 스택을 설치합니다

set -e

# 환경변수
MGMT_IP=${MGMT_IP:-"192.168.100.10"}
SDN_IP=${SDN_IP:-"192.168.100.20"}
K8S_MASTER_IP=${K8S_MASTER_IP:-"192.168.100.30"}
NETWORK_SUBNET=${NETWORK_SUBNET:-"192.168.100"}
K8S_WORKER_START_IP=${K8S_WORKER_START_IP:-"31"}
K8S_WORKER_COUNT=${K8S_WORKER_COUNT:-"2"}

echo "=== 네트워크 설정 ==="
MAIN_CON=$(nmcli -t -f NAME,DEVICE con show | grep -E "(eth0|ens33|ens160)" | head -1 | cut -d: -f1)

if [ -n "$MAIN_CON" ]; then
    echo "메인 연결 발견: $MAIN_CON"
    nmcli con mod "$MAIN_CON" ipv4.method manual
    nmcli con mod "$MAIN_CON" ipv4.addresses "${MGMT_IP}/24"
    nmcli con mod "$MAIN_CON" ipv4.gateway "${NETWORK_SUBNET}.1"
    nmcli con mod "$MAIN_CON" ipv4.dns "168.126.63.1"
    nmcli con down "$MAIN_CON" && nmcli con up "$MAIN_CON"
fi

echo "=== 관리 도구 설치 ==="
# EPEL 저장소 추가
dnf install -y epel-release

# Ansible 설치
dnf install -y ansible

# Git 설치
dnf install -y git

# Python 패키지 설치
pip3 install prometheus-client

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

echo "=== Ansible 디렉토리 생성 ==="
mkdir -p /opt/ansible/{inventory,playbooks,roles}
chown -R vagrant:vagrant /opt/ansible

echo "=== Management Server 설정 완료 ==="
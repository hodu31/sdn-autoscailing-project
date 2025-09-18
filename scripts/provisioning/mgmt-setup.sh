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


echo "=== 필수 패키지 설치 ==="
# 필수 패키지 설치
dnf install -y python3 vim curl git
dnf install -y python3-pip
# Python 패키지 설치
pip3 install prometheus-client


echo "=== 관리 도구 설치 ==="
# EPEL 저장소 추가
dnf install -y epel-release

# Ansible 설치
dnf install -y ansible

echo "=== Hosts 파일 업데이트 ==="
# 기존 항목이 있으면 제거
sed -i '/mgmt-server/d' /etc/hosts
sed -i '/sdn-controller/d' /etc/hosts
sed -i '/k8s-master/d' /etc/hosts
sed -i '/k8s-worker/d' /etc/hosts

# 새로운 항목 추가
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
#!/bin/bash

# Kubernetes Worker 설정 스크립트
# Worker 노드 전용 설정을 담당합니다

set -e

# 환경변수 (Vagrantfile에서 전달)
WORKER_IP=${WORKER_IP}
WORKER_NUM=${WORKER_NUM}
MGMT_IP=${MGMT_IP:-"192.168.100.10"}
SDN_IP=${SDN_IP:-"192.168.100.20"}
K8S_MASTER_IP=${K8S_MASTER_IP:-"192.168.100.30"}
NETWORK_SUBNET=${NETWORK_SUBNET:-"192.168.100"}
K8S_WORKER_START_IP=${K8S_WORKER_START_IP:-"31"}
K8S_WORKER_COUNT=${K8S_WORKER_COUNT:-"2"}

echo "=== Worker${WORKER_NUM} 네트워크 설정 ==="
MAIN_CON=$(nmcli -t -f NAME,DEVICE con show | grep -E "(eth0|ens33|ens160)" | head -1 | cut -d: -f1)

if [ -n "$MAIN_CON" ]; then
    nmcli con mod "$MAIN_CON" ipv4.method manual
    nmcli con mod "$MAIN_CON" ipv4.addresses "${WORKER_IP}/24"
    nmcli con mod "$MAIN_CON" ipv4.gateway "${NETWORK_SUBNET}.1"
    nmcli con mod "$MAIN_CON" ipv4.dns "168.126.63.1"
    nmcli con down "$MAIN_CON" && nmcli con up "$MAIN_CON"
fi

echo "=== 방화벽 설정 (Kubernetes Worker 포트) ==="
firewall-cmd --permanent --add-port=10250/tcp     # kubelet
firewall-cmd --permanent --add-port=10255/tcp     # kubelet read-only
firewall-cmd --permanent --add-port=30000-32767/tcp # NodePort Services
firewall-cmd --permanent --add-port=6783/tcp      # Flannel
firewall-cmd --reload

echo "=== Hosts 파일 업데이트 ==="
cat <<EOF >> /etc/hosts
${MGMT_IP} mgmt-server
${SDN_IP} sdn-controller
${K8S_MASTER_IP} k8s-master
EOF

# 워커 노드들도 hosts에 추가
for j in $(seq 1 ${K8S_WORKER_COUNT}); do
    worker_ip=$((${K8S_WORKER_START_IP} + j - 1))
    echo "${NETWORK_SUBNET}.${worker_ip} k8s-worker${j}" >> /etc/hosts
done

echo "=== kubectl 자동완성 설정 ==="
echo 'source <(kubectl completion bash)' >> /home/vagrant/.bashrc
echo 'alias k=kubectl' >> /home/vagrant/.bashrc
echo 'complete -F __start_kubectl k' >> /home/vagrant/.bashrc

# admin 사용자용도 설정
echo 'source <(kubectl completion bash)' >> /home/admin/.bashrc
echo 'alias k=kubectl' >> /home/admin/.bashrc
echo 'complete -F __start_kubectl k' >> /home/admin/.bashrc

echo "=== Kubernetes Worker${WORKER_NUM} 설정 완료 ==="
#!/bin/bash

# SDN Controller 시작 스크립트

set -e

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== SDN Controller 시작 ===${NC}"

# Ryu Controller가 설치되어 있는지 확인
if ! command -v ryu-manager &> /dev/null; then
    echo -e "${RED}Ryu Controller가 설치되지 않았습니다.${NC}"
    echo "설치 중..."
    pip3 install ryu eventlet
fi

# OpenVSwitch 서비스 확인
if ! systemctl is-active --quiet openvswitch; then
    echo -e "${BLUE}OpenVSwitch 서비스 시작 중...${NC}"
    systemctl start openvswitch
fi

# 가상 스위치 생성 (이미 존재하면 무시)
echo -e "${BLUE}가상 스위치 설정 중...${NC}"
ovs-vsctl --may-exist add-br br0
ovs-vsctl set-controller br0 tcp:127.0.0.1:6633

# SDN Controller 애플리케이션 시작
echo -e "${BLUE}Ryu SDN Controller 시작 중...${NC}"
cd /vagrant/sdn

# 백그라운드에서 실행
nohup ryu-manager --verbose load_balancer.py > /var/log/ryu-controller.log 2>&1 &

echo $! > /var/run/ryu-controller.pid

echo -e "${GREEN}=== SDN Controller 시작 완료 ===${NC}"
echo ""
echo "• Controller 로그: /var/log/ryu-controller.log"
echo "• OpenFlow 포트: 6633"
echo "• 가상 스위치: br0"
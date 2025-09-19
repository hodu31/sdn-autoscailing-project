#!/bin/bash

# 모니터링 스택 시작 스크립트
# Management Server에서 실행됩니다

set -e

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 모니터링 스택 시작 ===${NC}"

# 모니터링 디렉토리로 이동
cd /monitoring

# Docker Compose로 서비스 시작
echo -e "${BLUE}Docker Compose 서비스 시작 중...${NC}"
docker compose up -d

# 서비스 상태 확인
echo -e "${BLUE}서비스 상태 확인 중...${NC}"
sleep 10
docker compose ps

echo -e "${GREEN}=== 모니터링 스택 시작 완료 ===${NC}"
echo ""
echo "접속 정보:"
echo "• Prometheus: http://192.168.100.10:9090"
echo "• Grafana: http://192.168.100.10:3000 (admin/gkrltlfgdj!)"
echo "• AlertManager: http://192.168.100.10:9093"
echo "• Docker Registry: http://192.168.100.10:5000"
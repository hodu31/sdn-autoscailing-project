# 통합 DevOps 클러스터 관리 Makefile
# 빠른 명령어 실행을 위한 단축키 제공

.PHONY: help setup start stop restart status health info ssh-mgmt ssh-master clean destroy

# 기본 타겟
help: ## 도움말 표시
	@echo "🏗️  통합 DevOps 클러스터 관리 명령어"
	@echo "=================================="
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "예시:"
	@echo "  make setup     # 전체 클러스터 설정"
	@echo "  make status    # 클러스터 상태 확인"
	@echo "  make ssh-master # Kubernetes 마스터 접속"

# 클러스터 설정 및 관리
setup: ## 전체 클러스터 자동 설정 및 초기화
	@echo "🚀 클러스터 설정 시작..."
	@chmod +x setup-cluster.sh cluster-manager.sh
	@./setup-cluster.sh

start: ## 클러스터 시작
	@echo "▶️  클러스터 시작..."
	@./cluster-manager.sh start

stop: ## 클러스터 중지
	@echo "⏹️  클러스터 중지..."
	@./cluster-manager.sh stop

restart: ## 클러스터 재시작
	@echo "🔄 클러스터 재시작..."
	@./cluster-manager.sh restart

# 상태 확인
status: ## 클러스터 상태 확인
	@./cluster-manager.sh status

health: ## 헬스체크 수행
	@./cluster-manager.sh health

info: ## 클러스터 정보 출력
	@./cluster-manager.sh info

# SSH 접속 단축키
ssh-mgmt: ## Management 서버 접속
	@./cluster-manager.sh ssh mgmt

ssh-master: ## Kubernetes Master 접속
	@./cluster-manager.sh ssh k8s-master

ssh-sdn: ## SDN Controller 접속
	@./cluster-manager.sh ssh sdn

ssh-worker1: ## Worker1 접속
	@./cluster-manager.sh ssh k8s-worker1

ssh-worker2: ## Worker2 접속
	@./cluster-manager.sh ssh k8s-worker2

# Kubernetes 관련
k8s-nodes: ## Kubernetes 노드 상태 확인
	@echo "☸️  Kubernetes 노드 상태:"
	@vagrant ssh k8s-master -c "kubectl get nodes -o wide" 2>/dev/null || echo "Kubernetes 클러스터가 초기화되지 않았습니다"

k8s-pods: ## 모든 Pod 상태 확인
	@echo "📦 Pod 상태:"
	@vagrant ssh k8s-master -c "kubectl get pods --all-namespaces -o wide" 2>/dev/null || echo "Kubernetes 클러스터가 초기화되지 않았습니다"

k8s-services: ## 서비스 목록 확인
	@echo "🌐 서비스 목록:"
	@vagrant ssh k8s-master -c "kubectl get services --all-namespaces" 2>/dev/null || echo "Kubernetes 클러스터가 초기화되지 않았습니다"

# 개발 및 테스트
deploy-nginx: ## 테스트용 Nginx 배포
	@echo "🚀 Nginx 테스트 애플리케이션 배포..."
	@vagrant ssh k8s-master -c "kubectl create deployment nginx --image=nginx:alpine --replicas=3 && kubectl expose deployment nginx --type=NodePort --port=80" 2>/dev/null || echo "배포 실패 또는 이미 존재합니다"

test-scaling: ## 오토스케일링 테스트
	@echo "📈 오토스케일링 테스트 시작..."
	@vagrant ssh k8s-master -c "kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://nginx/; done'" || true

# 청소 및 리셋
clean: ## 클러스터 리셋 (설정 유지, 데이터만 삭제)
	@echo "🧹 클러스터 리셋..."
	@./cluster-manager.sh reset

destroy: ## 모든 VM 완전 삭제 (주의!)
	@echo "💥 모든 VM 삭제..."
	@./cluster-manager.sh destroy

# 로그 확인
logs-mgmt: ## Management 서버 로그
	@./cluster-manager.sh logs mgmt

logs-master: ## Kubernetes Master 로그
	@./cluster-manager.sh logs k8s-master

logs-sdn: ## SDN Controller 로그
	@./cluster-manager.sh logs sdn

# 모니터링 (향후 구현)
monitoring: ## 모니터링 스택 배포
	@echo "📊 모니터링 스택 배포 예정..."
	@echo "Prometheus: http://192.168.100.10:9090"
	@echo "Grafana: http://192.168.100.10:3000"

# 네트워크 테스트
network-test: ## 네트워크 연결 테스트
	@echo "🔗 네트워크 연결 테스트..."
	@vagrant ssh mgmt -c "for ip in 192.168.100.20 192.168.100.30 192.168.100.31 192.168.100.32; do echo -n 'Testing '$ip': '; ping -c 1 -W 2 $ip >/dev/null 2>&1 && echo 'OK' || echo 'FAIL'; done"

# 개발 환경 설정
dev-setup: ## 개발 환경 설정 (Ansible, kubectl 등)
	@echo "🛠️  개발 환경 설정..."
	@vagrant ssh mgmt -c "sudo dnf install -y ansible git vim kubectl"

# 백업 및 복원 (향후 구현)
backup: ## 클러스터 설정 백업
	@echo "💾 백업 기능 구현 예정..."

restore: ## 클러스터 설정 복원
	@echo "📥 복원 기능 구현 예정..."

# 업데이트
update: ## 시스템 패키지 업데이트
	@echo "📦 시스템 업데이트..."
	@for vm in mgmt sdn k8s-master k8s-worker1 k8s-worker2; do \
		echo "Updating $$vm..."; \
		vagrant ssh $$vm -c "sudo dnf update -y" 2>/dev/null || true; \
	done

# 설정 검증
validate: ## 설정 파일 검증
	@echo "✅ 설정 파일 검증..."
	@if [ ! -f "config.yaml" ]; then echo "❌ config.yaml 파일이 없습니다"; exit 1; fi
	@if [ ! -f "Vagrantfile" ]; then echo "❌ Vagrantfile이 없습니다"; exit 1; fi
	@echo "✅ 모든 설정 파일이 존재합니다"

# 포트 포워딩 (향후 구현)
port-forward: ## 주요 서비스 포트 포워딩 설정
	@echo "🌐 포트 포워딩 설정..."
	@echo "Kubernetes API: kubectl proxy --port=8080"
	@echo "직접 접속: ssh -L 8080:192.168.100.30:6443 vagrant@192.168.100.30"

# 프로젝트 정보
version: ## 프로젝트 버전 정보
	@echo "📋 프로젝트 정보"
	@echo "================"
	@echo "Project: 통합 DevOps 클러스터"
	@echo "Version: 1.0.0"
	@echo "Components: Kubernetes + SDN + Monitoring"
	@echo "VMs: 5개 (Management + SDN + K8s Master + 2x Worker)"
	@echo ""
	@vagrant --version 2>/dev/null || echo "Vagrant: 설치되지 않음"
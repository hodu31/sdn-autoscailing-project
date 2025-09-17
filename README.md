# 🏗️ 통합 DevOps 프로젝트

**완전 자동화된 SDN + Kubernetes + 모니터링 통합 인프라**

## 📁 프로젝트 구조

```
sdn-autoscaling-project/
├── Vagrantfile                    # 간소화된 VM 정의
├── config.yaml                    # 설정 파일
├── setup-cluster.sh               # 전체 클러스터 자동 설정
├── cluster-manager.sh             # 클러스터 관리 도구
├── Makefile                       # 빠른 명령어
├── README.md                      # 이 파일
│
├── scripts/                       # 🔧 실행 스크립트들
│   ├── provisioning/              # VM 프로비저닝 스크립트
│   │   ├── account-setup.sh       # 계정 및 SSH 설정
│   │   ├── network-setup.sh       # 기본 네트워크 설정
│   │   ├── docker-install.sh      # Docker 설치
│   │   ├── containerd-setup.sh    # containerd 설정
│   │   ├── k8s-install.sh         # Kubernetes 패키지 설치
│   │   ├── mgmt-setup.sh          # Management Server 설정
│   │   ├── sdn-setup.sh           # SDN Controller 설정
│   │   ├── k8s-master-setup.sh    # K8s Master 설정
│   │   └── k8s-worker-setup.sh    # K8s Worker 설정
│   ├── start-monitoring.sh        # 모니터링 스택 시작
│   └── start-sdn.sh               # SDN Controller 시작
│
├── monitoring/                    # 📊 모니터링 설정
│   ├── docker-compose.yml         # 모니터링 스택 (Prometheus, Grafana, AlertManager)
│   ├── prometheus/
│   │   ├── prometheus.yml         # Prometheus 설정
│   │   └── alert-rules.yml        # 알림 규칙
│   ├── alertmanager/
│   │   └── alertmanager.yml       # AlertManager 설정
│   └── grafana/
│       ├── datasources/           # 데이터소스 설정
│       └── dashboards/            # 대시보드 설정
│
├── sdn/                           # 🌐 SDN 애플리케이션
│   └── load_balancer.py           # Ryu 로드밸런서
│
├── k8s-manifests/                 # ☸️ Kubernetes 매니페스트
│   ├── applications/
│   │   └── nginx-app.yml          # 샘플 애플리케이션 + HPA
│   └── monitoring/
│       └── node-exporter.yml     # 노드 모니터링
│
└── ansible/                       # 🤖 Ansible 자동화
    ├── inventory/
    │   └── hosts.yml              # 서버 인벤토리
    └── playbooks/
        └── setup-k8s-cluster.yml # K8s 클러스터 설정
```

## 🚀 주요 개선사항

### ✨ 파일 분리 및 모듈화
- **Vagrantfile 간소화**: 긴 스크립트들을 별도 파일로 분리
- **재사용 가능한 스크립트**: 각 기능별로 독립적인 스크립트 파일
- **Docker Compose**: 모니터링 스택을 컨테이너로 관리
- **Kubernetes 매니페스트**: 애플리케이션 배포 템플릿

### 🔧 스크립트 구조
```bash
scripts/provisioning/
├── account-setup.sh      # 계정 설정 (재사용 가능)
├── network-setup.sh      # 네트워크 설정 (재사용 가능)
├── docker-install.sh     # Docker 설치 (재사용 가능)
└── [role]-setup.sh       # 역할별 전용 설정
```

## 📊 모니터링 스택

### Docker Compose 기반 모니터링
```bash
# Management Server에서 실행
vagrant ssh mgmt
./scripts/start-monitoring.sh

# 접속 URL
- Prometheus: http://192.168.100.10:9090
- Grafana: http://192.168.100.10:3000
- AlertManager: http://192.168.100.10:9093
```

### 포함된 서비스
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 대시보드 및 시각화
- **AlertManager**: 알림 관리
- **Node Exporter**: 시스템 메트릭
- **cAdvisor**: 컨테이너 메트릭
- **Docker Registry**: 프라이빗 이미지 저장소

## 🌐 SDN 네트워킹

### Ryu Controller
```bash
# SDN Controller에서 실행
vagrant ssh sdn
./scripts/start-sdn.sh

# 기능
- 로드밸런싱 (라운드 로빈)
- OpenFlow 기반 트래픽 제어
- 가상 스위치 관리
```

## ☸️ Kubernetes 배포

### 샘플 애플리케이션 배포
```bash
# K8s Master에서 실행
vagrant ssh k8s-master
kubectl apply -f /vagrant/k8s-manifests/applications/nginx-app.yml
kubectl apply -f /vagrant/k8s-manifests/monitoring/node-exporter.yml

# 배포 확인
kubectl get pods,svc,hpa
```

### Auto Scaling 테스트
```bash
# 부하 생성 테스트
make test-scaling

# HPA 상태 확인
kubectl get hpa nginx-hpa --watch
```

## 🔧 사용법

### 1. 빠른 시작
```bash
# 전체 자동 설정
make setup

# 개별 서비스 시작
make start-monitoring    # 모니터링 스택
make start-sdn          # SDN Controller
```

### 2. 클러스터 관리
```bash
make start/stop/restart  # 클러스터 제어
make status             # 상태 확인
make health             # 헬스체크
make ssh-mgmt           # Management 접속
make ssh-master         # K8s Master 접속
```

### 3. 애플리케이션 배포
```bash
make deploy-nginx       # 테스트 앱 배포
make k8s-pods          # Pod 상태 확인
make k8s-services      # 서비스 확인
```

## 📈 모니터링 및 알림

### 자동 알림 설정
- **CPU 사용률 80% 초과**: 2분 후 경고
- **메모리 사용률 90% 초과**: 2분 후 크리티컬
- **디스크 공간 10% 미만**: 즉시 경고
- **노드 다운**: 1분 후 크리티컬
- **Pod 재시작 빈번**: 즉시 경고

### Webhook 알림
AlertManager가 Management Server의 웹훅으로 알림을 전송하여 자동 스케일링을 트리거할 수 있습니다.

## 🎯 핵심 특징

### ✨ 완전 모듈화
- 각 기능이 독립적인 파일로 분리
- 재사용 가능한 스크립트 구조
- 설정과 코드의 명확한 분리

### 🏗️ Production Ready
- Docker Compose 기반 서비스 관리
- Kubernetes 매니페스트 템플릿
- 포괄적인 모니터링 및 알림 시스템

### 🔄 자동화
- 원클릭 전체 인프라 구축
- 자동 스케일링 (HPA + Custom Metrics)
- 지능형 네트워크 관리 (SDN)

이제 **모든 구성 요소가 별도 파일로 분리**되어 유지보수성과 확장성이 크게 향상되었습니다! 🎉
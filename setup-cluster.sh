#!/bin/bash

# 통합 DevOps 클러스터 설정 스크립트
# 전체 클러스터를 자동으로 설정하고 초기화합니다

set -e  # 에러 발생시 스크립트 종료

# 색상 정의 (Windows 호환)
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
    # Windows 환경에서는 색상 비활성화
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    # Linux/macOS 환경에서만 색상 활성화
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 진행상황 표시
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percentage=$((current * 100 / total))
    echo -e "${BLUE}[${current}/${total}]${NC} (${percentage}%) ${description}"
}

# 전제조건 확인
check_prerequisites() {
    log_info "전제조건 확인 중..."
    
    # Vagrant 설치 확인
    if ! command -v vagrant &> /dev/null; then
        log_error "Vagrant가 설치되지 않았습니다."
        log_error "https://www.vagrantup.com/ 에서 다운로드하여 설치해주세요."
        exit 1
    fi
    
    # Vagrant 버전 확인
    local vagrant_version=$(vagrant --version | awk '{print $2}')
    log_info "Vagrant 버전: $vagrant_version"
    
    # VMware 또는 VirtualBox 확인
    local has_provider=false
    if vagrant plugin list | grep -q "vagrant-vmware-desktop"; then
        log_info "VMware Desktop 플러그인 발견"
        has_provider=true
    fi
    
    if vagrant plugin list | grep -q "vagrant-vbguest"; then
        log_info "VirtualBox 플러그인 발견"
        has_provider=true
    fi
    
    if [[ "$has_provider" == false ]]; then
        log_warning "VMware Desktop 또는 VirtualBox 플러그인을 찾을 수 없습니다."
        log_warning "계속 진행하지만 문제가 발생할 수 있습니다."
    fi
    
    # 충분한 리소스 확인
    local total_memory=$((3072 + 1536 + 3072 + 2560 * 2))  # MB
    log_info "필요한 총 메모리: ${total_memory}MB (약 12GB)"
    log_warning "시스템에 충분한 메모리가 있는지 확인해주세요."
    
    log_success "전제조건 확인 완료"
}

# VM 상태 확인
check_vm_status() {
    local vm_name=$1
    local status
    
    # Vagrant 상태 확인 (에러 처리 개선)
    status=$(vagrant status "$vm_name" 2>/dev/null | grep -E "^$vm_name\s+" | awk '{print $2}' 2>/dev/null || echo "unknown")
    echo "$status"
}

# 단계별 VM 시작
start_vms() {
    log_info "VM들을 단계별로 시작합니다..."
    
    local vms=("mgmt" "sdn" "k8s-master" "k8s-worker1" "k8s-worker2")
    local total=${#vms[@]}
    
    for i in "${!vms[@]}"; do
        local vm=${vms[$i]}
        local current=$((i + 1))
        
        show_progress $current $total "VM ${vm} 시작 중..."
        
        local status=$(check_vm_status "$vm")
        if [[ "$status" != "running" ]]; then
            if vagrant up "$vm"; then
                log_success "${vm} 시작 완료"
                
                # VM이 완전히 시작될 때까지 대기
                log_info "${vm} 부팅 완료 대기 중..."
                sleep 30
                
                # SSH 연결 테스트
                local retry_count=0
                while [[ $retry_count -lt 10 ]]; do
                    if vagrant ssh "$vm" -c "echo 'SSH 연결 성공'" &> /dev/null; then
                        log_success "${vm} SSH 연결 확인됨"
                        break
                    fi
                    log_warning "${vm} SSH 연결 대기 중... (${retry_count}/10)"
                    sleep 10
                    ((retry_count++))
                done
                
                if [[ $retry_count -eq 10 ]]; then
                    log_error "${vm} SSH 연결 실패"
                    log_warning "수동으로 확인이 필요할 수 있습니다"
                fi
            else
                log_error "${vm} 시작 실패"
                exit 1
            fi
        else
            log_success "${vm}은 이미 실행 중입니다"
        fi
    done
    
    log_success "모든 VM이 성공적으로 시작되었습니다"
}

# 네트워크 연결 테스트
test_network_connectivity() {
    log_info "VM 간 네트워크 연결 테스트 중..."
    
    local mgmt_ip="192.168.100.10"
    local test_ips=("192.168.100.20" "192.168.100.30" "192.168.100.31" "192.168.100.32")
    
    # Management VM이 실행 중인지 확인
    local mgmt_status=$(check_vm_status "mgmt")
    if [[ "$mgmt_status" != "running" ]]; then
        log_error "Management VM이 실행 중이 아닙니다"
        return 1
    fi
    
    local connection_success=0
    local total_tests=${#test_ips[@]}
    
    for ip in "${test_ips[@]}"; do
        if vagrant ssh mgmt -c "ping -c 2 $ip" &> /dev/null; then
            log_success "mgmt -> $ip 연결 OK"
            ((connection_success++))
        else
            log_warning "mgmt -> $ip 연결 실패"
        fi
    done
    
    if [[ $connection_success -eq $total_tests ]]; then
        log_success "네트워크 연결 테스트 완료 ($connection_success/$total_tests)"
    else
        log_warning "일부 네트워크 연결 실패 ($connection_success/$total_tests)"
        log_warning "VM들이 완전히 부팅되지 않았을 수 있습니다"
    fi
}

# Ansible 설정
setup_ansible() {
    log_info "Ansible 설정 중..."
    
    # Management VM에 Ansible 설정 복사
    if vagrant ssh mgmt -c "
        sudo mkdir -p /opt/ansible/{inventory,playbooks,roles}
        sudo chown -R vagrant:vagrant /opt/ansible
    "; then
        log_success "Ansible 디렉토리 생성 완료"
    else
        log_error "Ansible 디렉토리 생성 실패"
        return 1
    fi
    
    # 인벤토리 파일 생성
    cat > temp_hosts.yml << 'EOF'
---
all:
  vars:
    ansible_user: vagrant
    ansible_ssh_pass: rmajsTlq!
    ansible_become: yes
    ansible_become_pass: rmajsTlq!
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    
  children:
    management:
      hosts:
        mgmt-server:
          ansible_host: 192.168.100.10
          
    sdn:
      hosts:
        sdn-controller:
          ansible_host: 192.168.100.20
          
    k8s_master:
      hosts:
        k8s-master:
          ansible_host: 192.168.100.30
          
    k8s_workers:
      hosts:
        k8s-worker1:
          ansible_host: 192.168.100.31
        k8s-worker2:
          ansible_host: 192.168.100.32
EOF
    
    # 파일을 Management VM으로 복사
    if vagrant upload temp_hosts.yml /tmp/hosts.yml mgmt && \
       vagrant ssh mgmt -c "
        sudo mv /tmp/hosts.yml /opt/ansible/inventory/
        sudo chown vagrant:vagrant /opt/ansible/inventory/hosts.yml
    "; then
        log_success "Ansible 인벤토리 파일 복사 완료"
    else
        log_error "Ansible 인벤토리 파일 복사 실패"
    fi
    
    # 임시 파일 삭제
    rm -f temp_hosts.yml
    
    # Ansible 연결 테스트
    log_info "Ansible 연결 테스트 중..."
    if vagrant ssh mgmt -c "cd /opt/ansible && ansible all -i inventory/hosts.yml -m ping" 2>/dev/null | grep -q "SUCCESS"; then
        log_success "Ansible 연결 테스트 성공"
    else
        log_warning "Ansible 연결 테스트 실패 - 수동으로 확인 필요"
        log_warning "VM들이 완전히 준비되지 않았을 수 있습니다"
    fi
}

# Kubernetes 클러스터 초기화
initialize_kubernetes() {
    log_info "Kubernetes 클러스터 초기화 중..."
    
    # Kubernetes Master가 실행 중인지 확인
    local master_status=$(check_vm_status "k8s-master")
    if [[ "$master_status" != "running" ]]; then
        log_error "Kubernetes Master VM이 실행 중이 아닙니다"
        return 1
    fi
    
    # Master 노드 초기화 확인
    if vagrant ssh k8s-master -c "sudo test -f /etc/kubernetes/admin.conf"; then
        log_success "Kubernetes 클러스터가 이미 초기화되어 있습니다"
    else
        # Master 노드 초기화
        log_info "Kubernetes Master 초기화 중..."
        if vagrant ssh k8s-master -c "
            sudo kubeadm init \
                --apiserver-advertise-address=192.168.100.30 \
                --pod-network-cidr=10.244.0.0/16 \
                --node-name=k8s-master
        "; then
            log_success "Kubernetes Master 초기화 완료"
        else
            log_error "Kubernetes Master 초기화 실패"
            return 1
        fi
    fi
    
    # kubeconfig 설정
    log_info "kubeconfig 설정 중..."
    vagrant ssh k8s-master -c "
        mkdir -p \$HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config
        sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
    "
    
    # Flannel CNI 설치
    log_info "Flannel CNI 설치 중..."
    if vagrant ssh k8s-master -c "
        kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    "; then
        log_success "Flannel CNI 설치 완료"
    else
        log_warning "Flannel CNI 설치 실패 - 수동으로 설치해야 할 수 있습니다"
    fi
    
    # Join 명령어 생성
    log_info "Worker 노드 Join 명령어 생성 중..."
    local join_command
    join_command=$(vagrant ssh k8s-master -c "sudo kubeadm token create --print-join-command" 2>/dev/null | tail -1)
    
    if [[ -n "$join_command" ]]; then
        log_success "Join 명령어 생성 완료"
        
        # Worker 노드 조인
        log_info "Worker 노드들을 클러스터에 조인 중..."
        for worker in k8s-worker1 k8s-worker2; do
            local worker_status=$(check_vm_status "$worker")
            if [[ "$worker_status" == "running" ]]; then
                log_info "${worker} 조인 중..."
                if vagrant ssh "$worker" -c "sudo $join_command"; then
                    log_success "${worker} 조인 완료"
                else
                    log_warning "${worker} 조인 실패"
                fi
            else
                log_warning "${worker}가 실행 중이 아닙니다"
            fi
        done
    else
        log_error "Join 명령어 생성 실패"
    fi
    
    # 클러스터 상태 확인
    log_info "클러스터 상태 확인 중..."
    sleep 30  # 노드들이 Ready 상태가 될 때까지 대기
    
    if vagrant ssh k8s-master -c "kubectl get nodes -o wide"; then
        log_success "Kubernetes 클러스터 초기화 완료"
    else
        log_warning "클러스터 상태 확인 실패"
    fi
}

# 기본 애플리케이션 배포
deploy_sample_app() {
    log_info "샘플 애플리케이션 배포 중..."
    
    local master_status=$(check_vm_status "k8s-master")
    if [[ "$master_status" != "running" ]]; then
        log_error "Kubernetes Master VM이 실행 중이 아닙니다"
        return 1
    fi
    
    if vagrant ssh k8s-master -c "
        # nginx 배포 확인
        if kubectl get deployment nginx &>/dev/null; then
            echo 'Nginx가 이미 배포되어 있습니다'
        else
            # nginx 배포
            kubectl create deployment nginx --image=nginx:alpine
            kubectl scale deployment nginx --replicas=3
            kubectl expose deployment nginx --type=NodePort --port=80
        fi
        
        # 배포 상태 확인
        echo '=== 배포 상태 ==='
        kubectl get deployments
        kubectl get pods
        kubectl get services
    "; then
        log_success "샘플 애플리케이션 배포 완료"
    else
        log_warning "샘플 애플리케이션 배포 실패"
    fi
}

# 상태 확인 및 정보 출력
show_cluster_info() {
    log_info "클러스터 정보 출력 중..."
    
    echo ""
    echo "==================================="
    echo "     클러스터 설정 완료!"
    echo "==================================="
    echo ""
    echo "📋 VM 정보:"
    echo "  • Management Server: 192.168.100.10"
    echo "  • SDN Controller:     192.168.100.20"
    echo "  • K8s Master:         192.168.100.30"
    echo "  • K8s Worker1:        192.168.100.31"
    echo "  • K8s Worker2:        192.168.100.32"
    echo ""
    echo "🔑 계정 정보:"
    echo "  • Username: vagrant / admin"
    echo "  • Password: rmajsTlq! / gkrltlfgdj!"
    echo ""
    echo "🚀 다음 단계:"
    echo "  1. ./cluster-manager.sh status     (클러스터 상태 확인)"
    echo "  2. ./cluster-manager.sh ssh mgmt   (Management 서버 접속)"
    echo "  3. ./cluster-manager.sh ssh k8s-master (Kubernetes 마스터 접속)"
    echo ""
    echo "📊 모니터링 시작 (Management VM에서):"
    echo "  • ./scripts/start-monitoring.sh"
    echo "  • Prometheus: http://192.168.100.10:9090"
    echo "  • Grafana: http://192.168.100.10:3000 (admin/gkrltlfgdj!)"
    echo ""
    echo "🌐 SDN Controller 시작 (SDN VM에서):"
    echo "  • ./scripts/start-sdn.sh"
    echo ""
    echo "☸️ Kubernetes 확인 (Master VM에서):"
    echo "  • kubectl get nodes -o wide"
    echo "  • kubectl get pods --all-namespaces"
    echo ""
}

# 메인 실행 함수
main() {
    echo ""
    echo "🏗️  통합 DevOps 클러스터 설정 시작"
    echo "====================================="
    echo ""
    
    # 1. 전제조건 확인
    show_progress 1 7 "전제조건 확인"
    check_prerequisites
    
    # 2. VM 시작
    show_progress 2 7 "VM 시작"
    start_vms
    
    # 3. 네트워크 테스트
    show_progress 3 7 "네트워크 연결 테스트"
    test_network_connectivity
    
    # 4. Ansible 설정
    show_progress 4 7 "Ansible 설정"
    setup_ansible
    
    # 5. Kubernetes 초기화
    show_progress 5 7 "Kubernetes 클러스터 초기화"
    initialize_kubernetes
    
    # 6. 샘플 앱 배포
    show_progress 6 7 "샘플 애플리케이션 배포"
    deploy_sample_app
    
    # 7. 정보 출력
    show_progress 7 7 "클러스터 정보 출력"
    show_cluster_info
    
    log_success "🎉 통합 DevOps 클러스터 설정이 완료되었습니다!"
    echo ""
    echo "🔧 추가 관리 명령어:"
    echo "  ./cluster-manager.sh help     # 도움말"
    echo "  ./cluster-manager.sh status   # 상태 확인"
    echo "  ./cluster-manager.sh health   # 헬스체크"
    echo ""
}

# 스크립트 실행
main "$@"
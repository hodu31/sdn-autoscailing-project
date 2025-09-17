#!/bin/bash

# 클러스터 관리 스크립트
# 클러스터 시작, 중지, 상태 확인, 리셋 등의 기능 제공

set -e

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

# VM 목록
VMS=("mgmt" "sdn" "k8s-master" "k8s-worker1" "k8s-worker2")

# 도움말 표시
show_help() {
    echo "클러스터 관리 스크립트"
    echo ""
    echo "사용법: $0 [명령어] [옵션]"
    echo ""
    echo "명령어:"
    echo "  start       클러스터 시작"
    echo "  stop        클러스터 중지"
    echo "  restart     클러스터 재시작"
    echo "  status      클러스터 상태 확인"
    echo "  reset       클러스터 리셋 (주의: 모든 데이터 삭제)"
    echo "  destroy     VM 삭제 (주의: 완전 삭제)"
    echo "  ssh <vm>    특정 VM에 SSH 접속"
    echo "  logs <vm>   특정 VM의 로그 확인"
    echo "  info        클러스터 정보 출력"
    echo "  health      헬스체크 수행"
    echo ""
    echo "VM 이름:"
    echo "  mgmt, sdn, k8s-master, k8s-worker1, k8s-worker2"
    echo ""
    echo "예시:"
    echo "  $0 start"
    echo "  $0 ssh k8s-master"
    echo "  $0 status"
}

# VM 상태 확인
get_vm_status() {
    local vm=$1
    local status
    
    # Vagrant 상태 확인 (에러 처리 개선)
    if command -v vagrant >/dev/null 2>&1; then
        status=$(vagrant status "$vm" 2>/dev/null | grep -E "^$vm\s+" | awk '{print $2}' 2>/dev/null || echo "unknown")
    else
        status="vagrant_not_found"
    fi
    
    echo "$status"
}

# 모든 VM 상태 표시
show_status() {
    log_info "클러스터 상태 확인 중..."
    echo ""
    printf "%-15s %-15s %-20s %-15s\n" "VM" "상태" "IP" "역할"
    echo "================================================================="
    
    local ips=("192.168.100.10" "192.168.100.20" "192.168.100.30" "192.168.100.31" "192.168.100.32")
    local roles=("Management" "SDN Controller" "K8s Master" "K8s Worker" "K8s Worker")
    
    for i in "${!VMS[@]}"; do
        local vm=${VMS[$i]}
        local status=$(get_vm_status "$vm")
        local ip=${ips[$i]}
        local role=${roles[$i]}
        
        # 상태에 따른 색상 적용
        case $status in
            "running")
                printf "%-15s ${GREEN}%-15s${NC} %-20s %-15s\n" "$vm" "$status" "$ip" "$role"
                ;;
            "poweroff"|"stopped"|"not_created")
                printf "%-15s ${RED}%-15s${NC} %-20s %-15s\n" "$vm" "$status" "$ip" "$role"
                ;;
            "vagrant_not_found")
                printf "%-15s ${RED}%-15s${NC} %-20s %-15s\n" "$vm" "Vagrant 없음" "$ip" "$role"
                ;;
            *)
                printf "%-15s ${YELLOW}%-15s${NC} %-20s %-15s\n" "$vm" "$status" "$ip" "$role"
                ;;
        esac
    done
    echo ""
}

# 클러스터 시작
start_cluster() {
    log_info "클러스터 시작 중..."
    
    for vm in "${VMS[@]}"; do
        local status=$(get_vm_status "$vm")
        if [[ "$status" != "running" ]]; then
            log_info "${vm} 시작 중..."
            if vagrant up "$vm"; then
                log_success "${vm} 시작 완료"
            else
                log_error "${vm} 시작 실패"
            fi
        else
            log_success "${vm}은 이미 실행 중입니다"
        fi
    done
    
    log_success "클러스터 시작 완료"
    show_status
}

# 클러스터 중지
stop_cluster() {
    log_info "클러스터 중지 중..."
    
    # 역순으로 중지 (워커 -> 마스터 -> 기타)
    local stop_order=("k8s-worker2" "k8s-worker1" "k8s-master" "sdn" "mgmt")
    
    for vm in "${stop_order[@]}"; do
        local status=$(get_vm_status "$vm")
        if [[ "$status" == "running" ]]; then
            log_info "${vm} 중지 중..."
            if vagrant halt "$vm"; then
                log_success "${vm} 중지 완료"
            else
                log_error "${vm} 중지 실패"
            fi
        else
            log_success "${vm}은 이미 중지되어 있습니다"
        fi
    done
    
    log_success "클러스터 중지 완료"
}

# 클러스터 재시작
restart_cluster() {
    log_info "클러스터 재시작 중..."
    stop_cluster
    sleep 5
    start_cluster
}

# 클러스터 리셋
reset_cluster() {
    log_warning "클러스터를 리셋하면 모든 설정과 데이터가 삭제됩니다!"
    echo -n "정말로 리셋하시겠습니까? (y/N): "
    read -r reply
    
    if [[ $reply =~ ^[Yy]$ ]]; then
        log_info "클러스터 리셋 중..."
        
        # Kubernetes 클러스터 리셋
        for vm in k8s-master k8s-worker1 k8s-worker2; do
            local status=$(get_vm_status "$vm")
            if [[ "$status" == "running" ]]; then
                log_info "${vm} Kubernetes 리셋 중..."
                vagrant ssh "$vm" -c "sudo kubeadm reset -f" 2>/dev/null || true
                vagrant ssh "$vm" -c "sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd" 2>/dev/null || true
            fi
        done
        
        # VM 재시작
        restart_cluster
        
        log_success "클러스터 리셋 완료"
    else
        log_info "리셋이 취소되었습니다"
    fi
}

# VM 삭제
destroy_cluster() {
    log_error "주의: 이 명령은 모든 VM을 완전히 삭제합니다!"
    log_error "모든 데이터와 설정이 영구적으로 손실됩니다!"
    echo ""
    echo -n "정말로 모든 VM을 삭제하시겠습니까? (y/N): "
    read -r reply
    
    if [[ $reply =~ ^[Yy]$ ]]; then
        echo -n "마지막 확인: 'DELETE'를 입력하세요: "
        read -r confirm
        if [[ "$confirm" == "DELETE" ]]; then
            log_info "모든 VM 삭제 중..."
            vagrant destroy -f
            log_success "모든 VM이 삭제되었습니다"
        else
            log_info "삭제가 취소되었습니다"
        fi
    else
        log_info "삭제가 취소되었습니다"
    fi
}

# 특정 VM에 SSH 접속
ssh_to_vm() {
    local vm=$1
    
    if [[ -z "$vm" ]]; then
        log_error "VM 이름을 지정해주세요"
        echo "사용 가능한 VM: ${VMS[*]}"
        exit 1
    fi
    
    # VM 이름 유효성 검사
    local valid_vm=false
    for valid in "${VMS[@]}"; do
        if [[ "$valid" == "$vm" ]]; then
            valid_vm=true
            break
        fi
    done
    
    if [[ "$valid_vm" == false ]]; then
        log_error "유효하지 않은 VM 이름: $vm"
        echo "사용 가능한 VM: ${VMS[*]}"
        exit 1
    fi
    
    local status=$(get_vm_status "$vm")
    if [[ "$status" != "running" ]]; then
        log_error "$vm이 실행 중이 아닙니다 (상태: $status)"
        exit 1
    fi
    
    log_info "$vm에 SSH 접속 중..."
    vagrant ssh "$vm"
}

# VM 로그 확인
show_vm_logs() {
    local vm=$1
    
    if [[ -z "$vm" ]]; then
        log_error "VM 이름을 지정해주세요"
        echo "사용 가능한 VM: ${VMS[*]}"
        exit 1
    fi
    
    local status=$(get_vm_status "$vm")
    if [[ "$status" != "running" ]]; then
        log_error "$vm이 실행 중이 아닙니다"
        exit 1
    fi
    
    log_info "$vm 로그 확인 중..."
    vagrant ssh "$vm" -c "sudo journalctl -f"
}

# 클러스터 정보 출력
show_cluster_info() {
    echo ""
    echo "🏗️  통합 DevOps 클러스터 정보"
    echo "=================================="
    echo ""
    
    show_status
    
    # Kubernetes 클러스터 정보
    local k8s_status=$(get_vm_status "k8s-master")
    if [[ "$k8s_status" == "running" ]]; then
        echo "☸️  Kubernetes 클러스터 정보:"
        echo "----------------------------------"
        if vagrant ssh k8s-master -c "kubectl get nodes -o wide 2>/dev/null"; then
            echo ""
        else
            log_warning "Kubernetes 클러스터가 초기화되지 않았습니다"
        fi
    fi
    
    echo "🔗 접속 정보:"
    echo "  • SSH: vagrant ssh [vm-name] 또는 ./cluster-manager.sh ssh [vm-name]"
    echo "  • 계정: vagrant/rmajsTlq!, admin/gkrltlfgdj!"
    echo ""
    
    echo "📚 유용한 명령어:"
    echo "  • kubectl get nodes          (노드 상태 확인)"
    echo "  • kubectl get pods --all-namespaces  (모든 Pod 확인)"
    echo "  • docker ps                  (컨테이너 확인)"
    echo ""
}

# 헬스체크 수행
perform_health_check() {
    log_info "클러스터 헬스체크 수행 중..."
    echo ""
    
    local issues=0
    
    # VM 상태 확인
    echo "1️⃣  VM 상태 확인:"
    for vm in "${VMS[@]}"; do
        local status=$(get_vm_status "$vm")
        if [[ "$status" == "running" ]]; then
            echo "  ✅ $vm: 정상"
        else
            echo "  ❌ $vm: 비정상 ($status)"
            ((issues++))
        fi
    done
    
    # 네트워크 연결 확인
    echo ""
    echo "2️⃣  네트워크 연결 확인:"
    local mgmt_status=$(get_vm_status "mgmt")
    if [[ "$mgmt_status" == "running" ]]; then
        local test_ips=("192.168.100.20" "192.168.100.30" "192.168.100.31" "192.168.100.32")
        for ip in "${test_ips[@]}"; do
            if vagrant ssh mgmt -c "ping -c 1 -W 2 $ip >/dev/null 2>&1" 2>/dev/null; then
                echo "  ✅ mgmt -> $ip: 연결 성공"
            else
                echo "  ❌ mgmt -> $ip: 연결 실패"
                ((issues++))
            fi
        done
    else
        echo "  ❌ Management VM이 실행 중이 아닙니다"
        ((issues++))
    fi
    
    # Kubernetes 클러스터 확인
    echo ""
    echo "3️⃣  Kubernetes 클러스터 확인:"
    local k8s_status=$(get_vm_status "k8s-master")
    if [[ "$k8s_status" == "running" ]]; then
        if vagrant ssh k8s-master -c "kubectl get nodes >/dev/null 2>&1" 2>/dev/null; then
            local ready_nodes=$(vagrant ssh k8s-master -c "kubectl get nodes --no-headers 2>/dev/null | grep -c Ready" 2>/dev/null || echo "0")
            echo "  ✅ Kubernetes API 서버: 정상"
            echo "  ✅ Ready 노드 수: $ready_nodes"
        else
            echo "  ❌ Kubernetes 클러스터가 초기화되지 않았습니다"
            ((issues++))
        fi
    else
        echo "  ❌ Kubernetes Master가 실행 중이 아닙니다"
        ((issues++))
    fi
    
    # 결과 출력
    echo ""
    if [[ $issues -eq 0 ]]; then
        log_success "✨ 모든 헬스체크 통과! 클러스터가 정상적으로 작동 중입니다."
    else
        log_warning "⚠️  $issues개의 문제가 발견되었습니다. 위 내용을 확인해주세요."
    fi
}

# 메인 함수
main() {
    case "${1:-help}" in
        "start")
            start_cluster
            ;;
        "stop")
            stop_cluster
            ;;
        "restart")
            restart_cluster
            ;;
        "status")
            show_status
            ;;
        "reset")
            reset_cluster
            ;;
        "destroy")
            destroy_cluster
            ;;
        "ssh")
            ssh_to_vm "$2"
            ;;
        "logs")
            show_vm_logs "$2"
            ;;
        "info")
            show_cluster_info
            ;;
        "health")
            perform_health_check
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
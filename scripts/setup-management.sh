#!/bin/bash
# setup-management.sh - Management Server 설정 스크립트

echo "=== Management Server 설정 시작 ==="

# 시스템 업데이트 건너뛰기 (시간 절약)
echo "기본 패키지만 설치합니다..."

# 필수 패키지 설치
echo "기본 패키지 설치 중..."
dnf install -y epel-release
dnf install -y wget curl vim git python3 python3-pip

# Ansible 설치
echo "Ansible 설치 중..."
dnf install -y ansible-core
pip3 install ansible docker-py kubernetes

# Prometheus 설치
echo "Prometheus 설치 중..."
cd /opt
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xzf prometheus-2.45.0.linux-amd64.tar.gz
mv prometheus-2.45.0.linux-amd64 prometheus
chown -R vagrant:vagrant prometheus

# Prometheus 설정 파일 생성 (IP 주소 수정됨)
cat > /opt/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['192.168.100.30:9100']
      
  - job_name: 'sdn-controller'
    static_configs:
      - targets: ['192.168.100.20:8080']
EOF

# Prometheus 서비스 파일 생성
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Server
After=network.target

[Service]
User=vagrant
Group=vagrant
Type=simple
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data --web.console.templates=/opt/prometheus/consoles --web.console.libraries=/opt/prometheus/console_libraries --web.listen-address=0.0.0.0:9090
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Grafana 설치
echo "Grafana 설치 중..."
dnf install -y https://dl.grafana.com/enterprise/release/grafana-enterprise-10.0.0-1.x86_64.rpm

# 서비스 시작 및 활성화
echo "서비스 시작 중..."
systemctl daemon-reload
systemctl enable --now prometheus
systemctl enable --now grafana-server

# 방화벽 설정
echo "방화벽 설정 중..."
firewall-cmd --permanent --add-port=9090/tcp  # Prometheus
firewall-cmd --permanent --add-port=3000/tcp  # Grafana
firewall-cmd --permanent --add-port=22/tcp    # SSH
firewall-cmd --reload

# SSH 키 생성 (다른 VM들과 통신용)
echo "SSH 키 생성 중..."
sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa

# Ansible 인벤토리 디렉터리 생성
mkdir -p /home/vagrant/ansible
chown -R vagrant:vagrant /home/vagrant/ansible

echo "=== Management Server 설정 완료 ==="
echo "Prometheus: http://192.168.100.10:9090"
echo "Grafana: http://192.168.100.10:3000 (admin/admin)"
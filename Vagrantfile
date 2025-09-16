# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# config.yaml 파일 로드
config_file = File.join(File.dirname(__FILE__), 'config.yaml')
if File.exist?(config_file)
  settings = YAML.load_file(config_file)
else
  puts "Warning: config.yaml not found. Using default values."
  settings = {}
end

# 설정값 가져오기 (YAML 파일 또는 기본값)
def get_setting(settings, key, default_value)
  settings[key] || default_value
end

Vagrant.configure("2") do |config|
  
  # config.yaml에서 설정값 로드
  root_password = get_setting(settings, 'ROOT_PASSWORD', 'defaultpass123')
  admin_password = get_setting(settings, 'ADMIN_PASSWORD', 'admin123')
  vagrant_password = get_setting(settings, 'VAGRANT_PASSWORD', 'vagrant')
  
  network_subnet = get_setting(settings, 'NETWORK_SUBNET', '192.168.100')
  mgmt_ip = get_setting(settings, 'MGMT_IP', '192.168.100.10')
  sdn_ip = get_setting(settings, 'SDN_IP', '192.168.100.20')
  app1_ip = get_setting(settings, 'APP1_IP', '192.168.100.30')
  
  mgmt_memory = get_setting(settings, 'MGMT_MEMORY', '2048').to_i
  sdn_memory = get_setting(settings, 'SDN_MEMORY', '1024').to_i
  app_memory = get_setting(settings, 'APP_MEMORY', '2048').to_i
  
  # 추가 설정값들
  grafana_admin_user = get_setting(settings, 'GRAFANA_ADMIN_USER', 'admin')
  grafana_admin_password = get_setting(settings, 'GRAFANA_ADMIN_PASSWORD', 'admin')
  prometheus_retention = get_setting(settings, 'PROMETHEUS_RETENTION', '168h')
  
  sdn_user = get_setting(settings, 'SDN_USER', 'sdn')
  openflow_port = get_setting(settings, 'OPENFLOW_PORT', '6653').to_i
  sdn_api_port = get_setting(settings, 'SDN_API_PORT', '8080').to_i
  
  # 공통 네트워크 설정 스크립트
  $network_script = <<-SCRIPT
    # 네트워크 설정
    nmcli con mod "System eth1" ipv4.method manual
    nmcli con mod "System eth1" ipv4.dns "168.126.63.1"
    nmcli con mod "System eth1" ipv4.gateway "#{network_subnet}.1"
    nmcli con down "System eth1" && nmcli con up "System eth1"
    
    # DNS 설정
    echo "nameserver 168.126.63.1" > /etc/resolv.conf
    
    # 방화벽 기본 설정
    systemctl restart NetworkManager
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload

    # Python3 설치 (Ansible 필수)
    dnf install -y python3 python3-pip

    echo "=== 기본 네트워크 설정 완료 ==="
  SCRIPT

  # 계정 설정 스크립트 (환경변수 사용)
  $account_setup = <<-SCRIPT
    # Root 계정 비밀번호 설정
    echo 'root:#{root_password}' | chpasswd
    
    # Vagrant 계정 비밀번호 변경
    echo 'vagrant:#{vagrant_password}' | chpasswd
    
    # 새 관리자 계정 생성
    useradd -m -s /bin/bash admin 2>/dev/null || true
    echo 'admin:#{admin_password}' | chpasswd
    usermod -aG wheel admin
    
    # SSH 설정 (Root 로그인 허용, 비밀번호 인증 활성화)
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    echo "=== 계정 설정 완료 ==="
    echo "Root: root/#{root_password}"
    echo "Admin: admin/#{admin_password}"
    echo "Vagrant: vagrant/#{vagrant_password}"
  SCRIPT
  
  # Management Server
  config.vm.define "mgmt" do |mgmt|
    mgmt.vm.box = "generic/rocky9"
    mgmt.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = mgmt_memory
      vmware.cpus = 2
      vmware.vmx["displayName"] = "mgmt-server"
    end
    mgmt.vm.hostname = "mgmt-server"
    mgmt.vm.synced_folder ".", "/vagrant", disabled: true
    
    # 고정 IP 설정
    mgmt.vm.network "private_network", 
      ip: mgmt_ip,
      netmask: "255.255.255.0"
    
    # 포트 포워딩
    mgmt.vm.network "forwarded_port", guest: 3000, host: 3000   # Grafana
    mgmt.vm.network "forwarded_port", guest: 9090, host: 9090   # Prometheus
    mgmt.vm.network "forwarded_port", guest: 22, host: 2210     # SSH
    
    # 프로비저닝 실행
    mgmt.vm.provision "shell", inline: $account_setup
    mgmt.vm.provision "shell", inline: $network_script
    mgmt.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "#{mgmt_ip}/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
    SHELL
    
    # 환경변수를 스크립트로 전달
    mgmt.vm.provision "shell", path: "scripts/setup-management.sh", 
      env: {
        "ROOT_PASSWORD" => root_password,
        "ADMIN_PASSWORD" => admin_password,
        "SDN_IP" => sdn_ip,
        "APP1_IP" => app1_ip,
        "GRAFANA_ADMIN_USER" => grafana_admin_user,
        "GRAFANA_ADMIN_PASSWORD" => grafana_admin_password,
        "PROMETHEUS_RETENTION" => prometheus_retention
      }
  end
  
  # SDN Controller
  config.vm.define "sdn" do |sdn|
    sdn.vm.box = "generic/rocky9"
    sdn.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = sdn_memory
      vmware.cpus = 2
      vmware.vmx["displayName"] = "sdn-server"
    end
    sdn.vm.hostname = "sdn-controller"
    sdn.vm.synced_folder ".", "/vagrant", disabled: true
    
    # 고정 IP 설정
    sdn.vm.network "private_network", 
      ip: sdn_ip,
      netmask: "255.255.255.0"
    
    # 포트 포워딩
    sdn.vm.network "forwarded_port", guest: openflow_port, host: openflow_port   # OpenFlow
    sdn.vm.network "forwarded_port", guest: sdn_api_port, host: sdn_api_port     # SDN API
    sdn.vm.network "forwarded_port", guest: 22, host: 2220                       # SSH
    
    # 프로비저닝 실행
    sdn.vm.provision "shell", inline: $account_setup
    sdn.vm.provision "shell", inline: $network_script
    sdn.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "#{sdn_ip}/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
      
      # SDN 사용자 생성
      useradd -m -s /bin/bash #{sdn_user} 2>/dev/null || true
      echo '#{sdn_user}:#{admin_password}' | chpasswd
      usermod -aG wheel #{sdn_user}
    SHELL
    
  end
  
  # Application Server
  config.vm.define "app1" do |app|
    app.vm.box = "generic/rocky9"
    app.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = app_memory
      vmware.cpus = 2
      vmware.vmx["displayName"] = "app1"
    end
    app.vm.hostname = "app-server1"
    app.vm.synced_folder ".", "/vagrant", disabled: true
    
    # 고정 IP 설정
    app.vm.network "private_network", 
      ip: app1_ip,
      netmask: "255.255.255.0"
    
    # 포트 포워딩
    app.vm.network "forwarded_port", guest: 80, host: 8081     # Web
    app.vm.network "forwarded_port", guest: 22, host: 2230     # SSH
    app.vm.network "forwarded_port", guest: 30000, host: 30000 # K8s NodePort
    
    # 프로비저닝 실행
    app.vm.provision "shell", inline: $account_setup
    app.vm.provision "shell", inline: $network_script
    app.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "#{app1_ip}/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
    SHELL
  end
end
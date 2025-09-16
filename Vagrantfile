# -*- mode: ruby -*-
# vi: set ft=ruby :

# .env 파일 로드
require 'dotenv'
Dotenv.load

# 환경변수가 없을 경우 기본값 설정
def get_env(key, default_value)
  ENV[key] || default_value
end

Vagrant.configure("2") do |config|
  
  # 환경변수에서 설정값 로드
  root_password = get_env('ROOT_PASSWORD', 'defaultpass123')
  admin_password = get_env('ADMIN_PASSWORD', 'admin123')
  network_subnet = get_env('NETWORK_SUBNET', '192.168.100')
  mgmt_ip = get_env('MGMT_IP', '192.168.100.10')
  sdn_ip = get_env('SDN_IP', '192.168.100.20')
  app1_ip = get_env('APP1_IP', '192.168.100.30')
  mgmt_memory = get_env('MGMT_MEMORY', '2048').to_i
  sdn_memory = get_env('SDN_MEMORY', '1024').to_i
  app_memory = get_env('APP_MEMORY', '2048').to_i
  
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
    
    # 새 관리자 계정 생성
    useradd -m -s /bin/bash admin
    echo 'admin:#{admin_password}' | chpasswd
    usermod -aG wheel admin
    
    # SSH 설정 (Root 로그인 허용, 비밀번호 인증 활성화)
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    echo "=== 계정 설정 완료 ==="
    echo "Root: root/#{root_password}"
    echo "Admin: admin/#{admin_password}"
    echo "Vagrant: vagrant/vagrant"
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
        "APP1_IP" => app1_ip
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
    sdn.vm.network "forwarded_port", guest: 6653, host: 6653   # OpenFlow
    sdn.vm.network "forwarded_port", guest: 8080, host: 8080   # SDN API
    sdn.vm.network "forwarded_port", guest: 22, host: 2220     # SSH
    
    # 프로비저닝 실행
    sdn.vm.provision "shell", inline: $account_setup
    sdn.vm.provision "shell", inline: $network_script
    sdn.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "#{sdn_ip}/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
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
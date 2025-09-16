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

# 설정값 가져오기
def get_setting(settings, key, default_value)
  settings[key] || default_value
end

Vagrant.configure("2") do |config|
  
  # 설정값 로드
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
  
  # 네트워크 설정 스크립트 (단일 네트워크 인터페이스용)
  $network_script = <<-SCRIPT
    # 네트워크 인터페이스 확인
    echo "=== 네트워크 인터페이스 목록 ==="
    ip link show
    nmcli con show
    
    # 방화벽 설정
    systemctl start firewalld
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --permanent --zone=trusted --add-source=192.168.100.0/24
    firewall-cmd --reload
    
    # SELinux 설정
    setenforce 0 2>/dev/null || true
    
    # DNS 설정
    echo "nameserver 168.126.63.1" >> /etc/resolv.conf
    
    # 필수 패키지 설치
    dnf install -y python3 python3-pip net-tools
    
    echo "=== 기본 네트워크 설정 완료 ==="
  SCRIPT

  # 계정 및 SSH 설정 스크립트
  $account_ssh_setup = <<-SCRIPT
    # Root 계정 비밀번호 설정
    echo 'root:#{root_password}' | chpasswd
    
    # Vagrant 계정 비밀번호 변경
    echo 'vagrant:#{vagrant_password}' | chpasswd
    
    # 관리자 계정 생성
    useradd -m -s /bin/bash admin 2>/dev/null || true
    echo 'admin:#{admin_password}' | chpasswd
    usermod -aG wheel admin
    
    # sudoers 설정
    echo "vagrant ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/vagrant
    echo "admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/admin
    chmod 440 /etc/sudoers.d/vagrant
    chmod 440 /etc/sudoers.d/admin
    
    # SSH 설정
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    
    # SSH 키 설정
    mkdir -p /home/vagrant/.ssh
    chmod 700 /home/vagrant/.ssh
    if [ -f /home/vagrant/.ssh/authorized_keys ]; then
        chmod 600 /home/vagrant/.ssh/authorized_keys
    fi
    chown -R vagrant:vagrant /home/vagrant/.ssh
    
    # SSH 서비스 재시작
    systemctl restart sshd
    systemctl enable sshd
    
    echo "=== 계정 및 SSH 설정 완료 ==="
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
    
    # synced_folder 비활성화
    mgmt.vm.synced_folder ".", "/vagrant", disabled: true
    
    # Private 네트워크만 설정 (eth0로 설정됨)
    mgmt.vm.network "private_network", 
      ip: mgmt_ip,
      netmask: "255.255.255.0",
      adapter: 1  # 첫 번째 어댑터로 설정
    
    # 프로비저닝
    mgmt.vm.provision "shell", inline: $account_ssh_setup
    mgmt.vm.provision "shell", inline: $network_script
    
    # IP 설정 (eth0 기준)
    mgmt.vm.provision "shell", inline: <<-SHELL
      # 현재 네트워크 연결 확인 및 설정
      MAIN_CON=$(nmcli -t -f NAME,DEVICE con show | grep -E "(eth0|ens33|ens160)" | head -1 | cut -d: -f1)
      
      if [ -n "$MAIN_CON" ]; then
        echo "메인 연결 발견: $MAIN_CON"
        nmcli con mod "$MAIN_CON" ipv4.method manual
        nmcli con mod "$MAIN_CON" ipv4.addresses "#{mgmt_ip}/24"
        nmcli con mod "$MAIN_CON" ipv4.gateway "#{network_subnet}.0"
        nmcli con mod "$MAIN_CON" ipv4.dns "168.126.63.1"
        nmcli con down "$MAIN_CON" && nmcli con up "$MAIN_CON"
      else
        echo "WARNING: 메인 네트워크 연결을 찾을 수 없습니다"
        # 수동으로 IP 설정
        ip addr add #{mgmt_ip}/24 dev eth0 2>/dev/null || ip addr add #{mgmt_ip}/24 dev ens33 2>/dev/null
      fi
      
      # 네트워크 상태 확인
      echo "=== 최종 네트워크 상태 ==="
      ip addr show
      ip route show
      echo "==========================="
    SHELL
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
    
    # Private 네트워크만 설정
    sdn.vm.network "private_network", 
      ip: sdn_ip,
      netmask: "255.255.255.0",
      adapter: 1
    
    # 프로비저닝
    sdn.vm.provision "shell", inline: $account_ssh_setup
    sdn.vm.provision "shell", inline: $network_script
    
    sdn.vm.provision "shell", inline: <<-SHELL
      # 네트워크 설정
      MAIN_CON=$(nmcli -t -f NAME,DEVICE con show | grep -E "(eth0|ens33|ens160)" | head -1 | cut -d: -f1)
      
      if [ -n "$MAIN_CON" ]; then
        nmcli con mod "$MAIN_CON" ipv4.method manual
        nmcli con mod "$MAIN_CON" ipv4.addresses "#{sdn_ip}/24"
        nmcli con mod "$MAIN_CON" ipv4.gateway "#{network_subnet}.0"
        nmcli con mod "$MAIN_CON" ipv4.dns "168.126.63.1"
        nmcli con down "$MAIN_CON" && nmcli con up "$MAIN_CON"
      fi
      
      # SDN 사용자 생성
      useradd -m -s /bin/bash sdn 2>/dev/null || true
      echo 'sdn:#{admin_password}' | chpasswd
      usermod -aG wheel sdn
      
      # 네트워크 상태 확인
      ip addr show
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
    
    # Private 네트워크만 설정
    app.vm.network "private_network", 
      ip: app1_ip,
      netmask: "255.255.255.0",
      adapter: 1
    
    # 프로비저닝
    app.vm.provision "shell", inline: $account_ssh_setup
    app.vm.provision "shell", inline: $network_script
    
    app.vm.provision "shell", inline: <<-SHELL
      # 네트워크 설정
      MAIN_CON=$(nmcli -t -f NAME,DEVICE con show | grep -E "(eth0|ens33|ens160)" | head -1 | cut -d: -f1)
      
      if [ -n "$MAIN_CON" ]; then
        nmcli con mod "$MAIN_CON" ipv4.method manual
        nmcli con mod "$MAIN_CON" ipv4.addresses "#{app1_ip}/24"
        nmcli con mod "$MAIN_CON" ipv4.gateway "#{network_subnet}.0"
        nmcli con mod "$MAIN_CON" ipv4.dns "168.126.63.1"
        nmcli con down "$MAIN_CON" && nmcli con up "$MAIN_CON"
      fi
      
      # 네트워크 상태 확인
      ip addr show
    SHELL
  end
end
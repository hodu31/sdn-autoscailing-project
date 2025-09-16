# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  
  # 공통 네트워크 설정 스크립트
  $network_script = <<-SCRIPT
    # 네트워크 설정
    nmcli con mod "System eth1" ipv4.method manual
    nmcli con mod "System eth1" ipv4.dns "168.126.63.1"
    nmcli con mod "System eth1" ipv4.gateway "192.168.100.1"
    nmcli con down "System eth1" && nmcli con up "System eth1"
    
    # DNS 설정 확인
    echo "nameserver 168.126.63.1" > /etc/resolv.conf
    
    # 방화벽 설정
    systemctl restart NetworkManager
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload

    echo "=== 네트워크 설정 완료 ==="
  SCRIPT

  $account_setup = <<-SCRIPT
    # Root 계정 비밀번호 설정
    echo 'root:dksgo1234' | chpasswd
    
    # SSH root 로그인 허용 (필요한 경우)
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
    
    echo "=== 계정 설정 완료 ==="
  SCRIPT
  
  # 인프라 자동화 및 메트릭수집 vm  (Ansible + Monitoring)
  config.vm.define "mgmt" do |mgmt|
    mgmt.vm.box = "generic/rocky9"
    mgmt.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = "1024"
      vmware.cpus = 2
      vmware.vmx["displayName"] = "mgmt-server"
    end
    mgmt.vm.hostname = "mgmt-server"
    mgmt.vm.synced_folder ".", "/vagrant", disabled: true
    
    # 고정 IP 설정
    mgmt.vm.network "private_network", 
      ip: "192.168.100.10",
      netmask: "255.255.255.0",
      gateway: "192.168.100.1"
    
    # 모니터링 서비스 포트 포워딩
    mgmt.vm.network "forwarded_port", guest: 3000, host: 3000
    mgmt.vm.network "forwarded_port", guest: 9090, host: 9090
    
    # 프로비저닝 실행
    mgmt.vm.provision "shell", inline: $account_setup
    mgmt.vm.provision "shell", inline: $network_script
    mgmt.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "192.168.100.10/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
    SHELL
    
    # 프로비저닝 스크립트
    mgmt.vm.provision "shell", path: "scripts/setup-management.sh"
  end
  
  # SDN 컨트롤러 vm
  config.vm.define "sdn" do |sdn|
    sdn.vm.box = "generic/rocky9"
    sdn.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = "1024"
      vmware.cpus = 2
      vmware.vmx["displayName"] = "sdn-server"
    end
    sdn.vm.hostname = "sdn-controller"
    sdn.vm.synced_folder ".", "/vagrant", disabled: true
    
    # 고정 IP 설정
    sdn.vm.network "private_network", 
      ip: "192.168.100.20",
      netmask: "255.255.255.0",
      gateway: "192.168.100.1"
    
    # 프로비저닝 실행
    sdn.vm.provision "shell", inline: $account_setup  # 수정됨
    sdn.vm.provision "shell", inline: $network_script
    sdn.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "192.168.100.20/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
    SHELL
  end
  
  # 어플리케이션 vm
  config.vm.define "app1" do |app|
    app.vm.box = "generic/rocky9"
    app.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = "2048"
      vmware.cpus = 2
      vmware.vmx["displayName"] = "app1"
    end
    app.vm.hostname = "app-server1"
    app.vm.synced_folder ".", "/vagrant", disabled: true
    
    # 고정 IP 설정
    app.vm.network "private_network", 
      ip: "192.168.100.30",
      netmask: "255.255.255.0",
      gateway: "192.168.100.1"
    
    # 웹서버 포트 포워딩
    app.vm.network "forwarded_port", guest: 80, host: 8080
    
    # 프로비저닝 실행
    app.vm.provision "shell", inline: $account_setup  # 수정됨
    app.vm.provision "shell", inline: $network_script
    app.vm.provision "shell", inline: <<-SHELL
      nmcli con mod "System eth1" ipv4.addresses "192.168.100.30/24"
      nmcli con down "System eth1" && nmcli con up "System eth1"
    SHELL
    
  end
  
  # 어플리케이션 vm 2 (추후 확장용)
  # config.vm.define "app2" do |app|
  #  app.vm.box = "generic/rocky9"
  #  app.vm.provider "vmware_desktop" do |vmware|
  #    vmware.gui = false
  #    vmware.memory = "1024"
  #    vmware.cpus = 2
  #    vmware.vmx["displayName"] = "app2"
  #  end
  #  app.vm.hostname = "app-server2"
  #  app.vm.synced_folder ".", "/vagrant", disabled: true
  #  
  #  # 고정 IP 설정
  #  app.vm.network "private_network", 
  #    ip: "192.168.100.31",
  #    netmask: "255.255.255.0",
  #    gateway: "192.168.100.1"
  #  
  #  # 프로비저닝 실행
  #  app.vm.provision "shell", inline: $account_setup
  #  app.vm.provision "shell", inline: $network_script
  #  app.vm.provision "shell", inline: <<-SHELL
  #    nmcli con mod "System eth1" ipv4.addresses "192.168.100.31/24"
  #    nmcli con down "System eth1" && nmcli con up "System eth1"
  #  SHELL
  #  
  #  # 프로비저닝 스크립트
  #  app.vm.provision "shell", path: "scripts/setup-docker.sh"
  #end
end
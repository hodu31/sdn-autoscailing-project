# -*- mode: ruby -*-
# vi: set ft=ruby :
Vagrant.configure("2") do |config|
  
  # 인프라 자동화 및 메트릭수집 vm  (Ansible + Monitoring)
  config.vm.define "mgmt" do |mgmt|
    mgmt.vm.box = "generic/rocky9"
    mgmt.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = "1024"
      vmware.cpus = 2
    end
    mgmt.vm.hostname = "mgmt-server"
    mgmt.vm.synced_folder ".", "/vagrant", disabled: true
    # NAT 네트워크로 변경
    mgmt.vm.network "private_network", ip: "192.168.100.10"
    # 모니터링 서비스 포트 포워딩
    mgmt.vm.network "forwarded_port", guest: 3000, host: 3000
    mgmt.vm.network "forwarded_port", guest: 9090, host: 9090
    
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
    end
    sdn.vm.hostname = "sdn-controller"
    sdn.vm.synced_folder ".", "/vagrant", disabled: true
    sdn.vm.network "private_network", ip: "192.168.100.20"
    
    sdn.vm.provision "shell", path: "scripts/setup-sdn.sh"
  end
  
  # 어플리케이션 vm
  config.vm.define "app1" do |app|
    app.vm.box = "generic/rocky9"
    app.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = "2048"
      vmware.cpus = 2
    end
    app.vm.hostname = "app-server1"
    app.vm.synced_folder ".", "/vagrant", disabled: true
    app.vm.network "private_network", ip: "192.168.100.30"
    # 웹서버 포트 포워딩
    app.vm.network "forwarded_port", guest: 80, host: 8080
    
    app.vm.provision "shell", path: "scripts/setup-docker.sh"
  end
  
  # 어플리케이션 vm 2 (추후 확장용)
  # config.vm.define "app2" do |app|
  #  app.vm.box = "generic/rocky9"
  #  app.vm.provider "vmware_desktop" do |vmware|
  #    vmware.gui = false
  #    vmware.memory = "1024"
  #    vmware.cpus = 2
  #  end
  #  app.vm.hostname = "app-server2"
  #  app.vm.synced_folder ".", "/vagrant", disabled: true
  #  app.vm.network "private_network", ip: "192.168.100.31"
    
    # 프로비저닝 스크립트
  #  app.vm.provision "shell", path: "scripts/setup-docker.sh"
  #end
end
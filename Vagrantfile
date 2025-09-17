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
  k8s_master_ip = get_setting(settings, 'K8S_MASTER_IP', '192.168.100.30')
  k8s_worker_start_ip = get_setting(settings, 'K8S_WORKER_START_IP', '31')
  
  mgmt_memory = get_setting(settings, 'MGMT_MEMORY', '2048').to_i
  sdn_memory = get_setting(settings, 'SDN_MEMORY', '1024').to_i
  k8s_master_memory = get_setting(settings, 'K8S_MASTER_MEMORY', '3072').to_i
  k8s_worker_memory = get_setting(settings, 'K8S_WORKER_MEMORY', '2048').to_i
  worker_count = get_setting(settings, 'K8S_WORKER_COUNT', 2).to_i

  # 공통 환경변수 설정
  common_env = {
    'ROOT_PASSWORD' => root_password,
    'ADMIN_PASSWORD' => admin_password,
    'VAGRANT_PASSWORD' => vagrant_password,
    'NETWORK_SUBNET' => network_subnet,
    'MGMT_IP' => mgmt_ip,
    'SDN_IP' => sdn_ip,
    'K8S_MASTER_IP' => k8s_master_ip,
    'K8S_WORKER_START_IP' => k8s_worker_start_ip,
    'K8S_WORKER_COUNT' => worker_count.to_s
  }
  
  # Management Server (VM1)
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
    mgmt.vm.network "private_network", ip: mgmt_ip, netmask: "255.255.255.0", adapter: 1
    
    # 프로비저닝 스크립트 실행
    mgmt.vm.provision "shell", path: "scripts/provisioning/account-setup.sh", env: common_env
    mgmt.vm.provision "shell", path: "scripts/provisioning/network-setup.sh", env: common_env
    mgmt.vm.provision "shell", path: "scripts/provisioning/docker-install.sh", env: common_env
    mgmt.vm.provision "shell", path: "scripts/provisioning/mgmt-setup.sh", env: common_env
  end
  
  # SDN Controller (VM2)
  config.vm.define "sdn" do |sdn|
    sdn.vm.box = "generic/rocky9"
    sdn.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = sdn_memory
      vmware.cpus = 2
      vmware.vmx["displayName"] = "sdn-controller"
    end
    
    sdn.vm.hostname = "sdn-controller"
    sdn.vm.synced_folder ".", "/vagrant", disabled: true
    sdn.vm.network "private_network", ip: sdn_ip, netmask: "255.255.255.0", adapter: 1
    
    # 프로비저닝 스크립트 실행
    sdn.vm.provision "shell", path: "scripts/provisioning/account-setup.sh", env: common_env
    sdn.vm.provision "shell", path: "scripts/provisioning/network-setup.sh", env: common_env
    sdn.vm.provision "shell", path: "scripts/provisioning/sdn-setup.sh", env: common_env
  end
  
  # Kubernetes Master (VM3)
  config.vm.define "k8s-master" do |master|
    master.vm.box = "generic/rocky9"
    master.vm.provider "vmware_desktop" do |vmware|
      vmware.gui = false
      vmware.memory = k8s_master_memory
      vmware.cpus = 2
      vmware.vmx["displayName"] = "k8s-master"
    end
    
    master.vm.hostname = "k8s-master"
    master.vm.synced_folder ".", "/vagrant", disabled: true
    master.vm.network "private_network", ip: k8s_master_ip, netmask: "255.255.255.0", adapter: 1
    
    # 프로비저닝 스크립트 실행
    master.vm.provision "shell", path: "scripts/provisioning/account-setup.sh", env: common_env
    master.vm.provision "shell", path: "scripts/provisioning/network-setup.sh", env: common_env
    master.vm.provision "shell", path: "scripts/provisioning/docker-install.sh", env: common_env
    master.vm.provision "shell", path: "scripts/provisioning/containerd-setup.sh", env: common_env
    master.vm.provision "shell", path: "scripts/provisioning/k8s-install.sh", env: common_env
    master.vm.provision "shell", path: "scripts/provisioning/k8s-master-setup.sh", env: common_env
  end
  
  # Kubernetes Workers (VM4+)
  (1..worker_count).each do |i|
    config.vm.define "k8s-worker#{i}" do |worker|
      worker.vm.box = "generic/rocky9"
      worker.vm.provider "vmware_desktop" do |vmware|
        vmware.gui = false
        vmware.memory = k8s_worker_memory
        vmware.cpus = 2
        vmware.vmx["displayName"] = "k8s-worker#{i}"
      end
      
      worker.vm.hostname = "k8s-worker#{i}"
      worker.vm.synced_folder ".", "/vagrant", disabled: true
      
      worker_ip = "#{network_subnet}.#{k8s_worker_start_ip.to_i + i - 1}"
      worker.vm.network "private_network", ip: worker_ip, netmask: "255.255.255.0", adapter: 1
      
      # Worker 전용 환경변수 추가
      worker_env = common_env.merge({
        'WORKER_IP' => worker_ip,
        'WORKER_NUM' => i.to_s
      })
      
      # 프로비저닝 스크립트 실행
      worker.vm.provision "shell", path: "scripts/provisioning/account-setup.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/provisioning/network-setup.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/provisioning/docker-install.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/provisioning/containerd-setup.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/provisioning/k8s-install.sh", env: worker_env
      worker.vm.provision "shell", path: "scripts/provisioning/k8s-worker-setup.sh", env: worker_env
    end
  end
end
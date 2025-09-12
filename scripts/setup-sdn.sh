#!/bin/bash
# setup-sdn.sh - SDN Controller 서버 설정 스크립트

echo "=== SDN Controller 설정 시작 ==="

# 시스템 업데이트 건너뛰기 (시간 절약)
echo "기본 패키지만 설치합니다..."

# 필수 패키지 설치
dnf install -y epel-release wget curl vim git python3 python3-pip

# SDN 관련 패키지 설치
dnf install -y openvswitch python3-openvswitch gcc make python3-devel

# Python SDN 라이브러리 설치
pip3 install ryu eventlet netaddr

# Open vSwitch 서비스 시작
systemctl enable --now openvswitch

# 기본 SDN Controller 코드 생성
mkdir -p /home/vagrant/sdn
cat > /home/vagrant/sdn/simple_controller.py << 'EOF'
from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet
from ryu.lib.packet import ethernet

class SimpleController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(SimpleController, self).__init__(*args, **kwargs)
        self.mac_to_port = {}

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                        ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)

    def add_flow(self, datapath, priority, match, actions):
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS,
                                           actions)]
        mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                              match=match, instructions=inst)
        datapath.send_msg(mod)
EOF

chmod +x /home/vagrant/sdn/*.py
chown -R vagrant:vagrant /home/vagrant/sdn

# 방화벽 설정
firewall-cmd --permanent --add-port=6653/tcp
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --reload

echo "=== SDN Controller 설정 완료 ==="
#!/usr/bin/env python3
"""
Ryu SDN Controller - Load Balancer
기본적인 로드밸런싱 기능을 제공하는 SDN 컨트롤러입니다.
"""

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER
from ryu.controller.handler import set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ipv4, tcp
import logging

class LoadBalancerController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(LoadBalancerController, self).__init__(*args, **kwargs)
        
        # MAC Address 테이블
        self.mac_to_port = {}
        
        # 로드밸런싱 서버 목록
        self.backend_servers = [
            '192.168.100.31',  # k8s-worker1
            '192.168.100.32',  # k8s-worker2
        ]
        
        # 라운드 로빈 인덱스
        self.server_index = 0
        
        # 가상 서비스 IP
        self.virtual_ip = '192.168.100.100'
        
        self.logger.info("SDN Load Balancer Controller 시작됨")

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """스위치 연결시 기본 플로우 설치"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        # 기본 플로우: 컨트롤러로 전송
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                        ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        
        self.logger.info("스위치 %s 연결됨", datapath.id)

    def add_flow(self, datapath, priority, match, actions, buffer_id=None):
        """플로우 테이블에 플로우 추가"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS,
                                           actions)]
        if buffer_id:
            mod = parser.OFPFlowMod(datapath=datapath, buffer_id=buffer_id,
                                  priority=priority, match=match,
                                  instructions=inst)
        else:
            mod = parser.OFPFlowMod(datapath=datapath, priority=priority,
                                  match=match, instructions=inst)
        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def packet_in_handler(self, ev):
        """패킷 인 이벤트 처리"""
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]

        dst = eth.dst
        src = eth.src
        dpid = datapath.id

        self.mac_to_port.setdefault(dpid, {})

        # MAC 주소 학습
        self.mac_to_port[dpid][src] = in_port

        # 목적지 포트 결정
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD

        actions = [parser.OFPActionOutput(out_port)]

        # 플로우 테이블에 추가 (flooding이 아닌 경우)
        if out_port != ofproto.OFPP_FLOOD:
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src)
            self.add_flow(datapath, 1, match, actions, msg.buffer_id)
            return

        # 패킷 아웃
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(datapath=datapath, buffer_id=msg.buffer_id,
                                in_port=in_port, actions=actions, data=data)
        datapath.send_msg(out)

    def get_next_server(self):
        """라운드 로빈으로 다음 서버 선택"""
        server = self.backend_servers[self.server_index]
        self.server_index = (self.server_index + 1) % len(self.backend_servers)
        return server

    def install_load_balancer_flows(self, datapath, dst_ip, dst_port):
        """로드밸런서 플로우 설치"""
        parser = datapath.ofproto_parser
        ofproto = datapath.ofproto
        
        # 선택된 백엔드 서버
        backend_ip = self.get_next_server()
        
        self.logger.info("로드밸런싱: %s -> %s", dst_ip, backend_ip)
        
        # TODO: 실제 NAT 플로우 규칙 구현
        # 여기서는 기본적인 포워딩만 구현됨
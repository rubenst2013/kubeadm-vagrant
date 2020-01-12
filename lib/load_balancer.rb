
require_relative 'vars'
require_relative 'helpers'

$lb_script = <<SCRIPT
#!/bin/bash

set -eo pipefail

status() {
    echo -e "\033[35m >>>   $*\033[0;39m"
}

status "Enabling port forwarding..."
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system


status "configuring haproxy and keepalived..."
apt-get install -y keepalived haproxy

systemctl stop keepalived || true

vrrp_if=$(ip a | grep 192.168.10 | awk '{print $7}')
vrrp_ip=$(ip a | grep 192.168.10 | awk '{split($2, a, "/"); print a[1]}')
vrrp_state="BACKUP"
vrrp_priority="100"
if [ "${vrrp_ip}" = "#{$PUBLIC_LOAD_BALANCER_IP_NW}11" ]; then
  vrrp_state="MASTER"
  vrrp_priority="101"
fi

cat > /etc/keepalived/keepalived.conf <<EOF
global_defs {
    router_id LVS_DEVEL
    script_user root root
}
vrrp_script check_loadbalancer {
    script "/etc/keepalived/check_loadbalancer.sh"
    interval 2
    weight -5
    fall 3
    rise 2
}
vrrp_instance VI_1 {
    state ${vrrp_state}
    interface ${vrrp_if}
    mcast_src_ip ${vrrp_ip}
    virtual_router_id 51
    priority ${vrrp_priority}
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass a6E/CHhJkCn1Ww1gF3qPiJTKTEc=
    }
    virtual_ipaddress {
        #{$PUBLIC_LOAD_BALANCER_IP}
    }
    track_script {
        check_loadbalancer
    }
}
EOF

cat > /etc/keepalived/check_loadbalancer.sh <<EOF
#!/bin/bash

errorExit() {
  echo "*** $*" 1>&2
  exit 1
}

killall -0 haproxy || errorExit "Error - haproxy not running"
ping -c 4 -w 2 -i 0.2 127.0.0.1 2>&1 >/dev/null || errorExit "Error - Local interface is not reachable"
if ip addr | grep -q #{$PUBLIC_LOAD_BALANCER_IP}; then
  ping -c 4 -w 2 -i 0.2 #{$PUBLIC_LOAD_BALANCER_IP} 2>&1 >/dev/null || errorExit "Error - Not reachable on public IP #{$PUBLIC_LOAD_BALANCER_IP}"
fi
EOF
chmod 744 /etc/keepalived/check_loadbalancer.sh

systemctl restart keepalived
sleep 10

cat > /etc/haproxy/haproxy.cfg <<EOF
global
  log /dev/log  local0
  log /dev/log  local1 notice
  chroot /var/lib/haproxy
  user haproxy
  group haproxy
  daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client 50s
    timeout client-fin 50s
    timeout server 50s
    timeout tunnel 1h

listen stats
    bind *:1080
    stats refresh 30s
    stats uri /stats

listen http
    bind *:80
    mode tcp
    option tcplog
    balance roundrobin
    default_backend http_back

listen https
    bind *:443
    mode tcp
    option tcplog
    balance roundrobin
    default_backend https_back

backend http_back
    mode tcp
#{gen_haproxy_lb_backend($NODE_COUNT, 80)}

backend https_back
    mode tcp
#{gen_haproxy_lb_backend($NODE_COUNT, 443)}
EOF

systemctl restart haproxy
SCRIPT
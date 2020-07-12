
require_relative 'vars'
require_relative 'helpers'

$ha_script = <<SCRIPT
#!/bin/bash

set -eo pipefail

status() {
    echo -e "\033[35m >>>   $*\033[0;39m"
}

status "configuring haproxy and keepalived.."
apt-get install -y keepalived haproxy

systemctl stop keepalived || true

vrrp_if=$(ip a | grep 192.168.26 | awk '{print $7}')
vrrp_ip=$(ip a | grep 192.168.26 | awk '{split($2, a, "/"); print a[1]}')
vrrp_state="BACKUP"
vrrp_priority="100"
if [ "${vrrp_ip}" = "#{$NODE_IP_NW}11" ]; then
  vrrp_state="MASTER"
  vrrp_priority="101"
fi

cat > /etc/keepalived/keepalived.conf <<EOF
global_defs {
    router_id LVS_DEVEL
    enable_script_security
    script_user root root
}
vrrp_script check_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
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
        #{$MASTER_IP}
    }
    track_script {
       check_apiserver
    }
}
EOF

cat > /etc/keepalived/check_apiserver.sh <<EOF
#!/bin/bash

errorExit() {
  echo "*** $*" 1>&2
  exit 1
}

curl --silent --max-time 2 --insecure https://localhost:6443/ -o /dev/null || errorExit "Error GET https://localhost:6443/"
if ip addr | grep -q #{$MASTER_IP}; then
  curl --silent --max-time 2 --insecure https://#{$MASTER_IP}:#{$MASTER_PORT}/ -o /dev/null || errorExit "Error GET https://#{$MASTER_IP}:#{$MASTER_PORT}/"
fi
EOF
chmod 744 /etc/keepalived/check_apiserver.sh

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
    mode    http
    option  httplog
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

listen kube-api-server
    bind #{$MASTER_IP}:#{$MASTER_PORT}
    mode tcp
    option tcplog
    balance roundrobin

#{gen_haproxy_master_backend($MASTER_COUNT)}
EOF

systemctl restart haproxy

status "Resetting cluster, please ignore possible warnings..."
kubeadm reset -f

if [ ${vrrp_state} = "MASTER" ]; then
  status "running kubeadm init on the first master node.."
  kubeadm init \
    --upload-certs \
    --token #{$KUBE_TOKEN} \
    --token-ttl 24h \
    --apiserver-advertise-address ${vrrp_ip} \
    --apiserver-bind-port 6443 \
    \
    --kubernetes-version v#{$KUBE_VER} \
    --control-plane-endpoint "#{$MASTER_IP}:#{$MASTER_PORT}" \
    --image-repository "#{$IMAGE_REPO}" \
    --pod-network-cidr "#{$POD_NW_CIDR}" \
    | tee /vagrant/kubeadm.log
else
  status "joining master node.."
  discovery_token_ca_cert_hash="$(grep 'discovery-token-ca-cert-hash' /vagrant/kubeadm.log | head -n1 | awk '{print $2}')"
  certificate_key="$(grep 'certificate-key' /vagrant/kubeadm.log | head -n1 | awk '{print $3}')"
  kubeadm join #{$MASTER_IP}:#{$MASTER_PORT} --token #{$KUBE_TOKEN} \
    --discovery-token-ca-cert-hash ${discovery_token_ca_cert_hash} \
    --control-plane --certificate-key ${certificate_key} \
    --apiserver-advertise-address ${vrrp_ip}
fi

status "installing additional tools for cluster operation..."
if [ ${vrrp_state} = "MASTER" ]; then
  mkdir -p $HOME/.kube
  cp -Rf /etc/kubernetes/admin.conf $HOME/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config

  cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
  chown vagrant:vagrant /home/vagrant/.kube/config

  status "Install and prepare helm k8s package manager"
  snap install helm --classic
  helm repo add stable https://kubernetes-charts.storage.googleapis.com/  #ToDo: Switch to helm hub in the future. https://helm.sh/blog/helm-v3-beta/
  helm repo update

  status "Register bash completion"
  echo 'source <(kubectl completion bash)' >> /etc/profile.d/k8s-tools.sh
  echo 'source <(helm completion bash)' >> /etc/profile.d/k8s-tools.sh
else
  true
fi


SCRIPT
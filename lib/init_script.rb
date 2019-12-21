require_relative 'vars'

$init_script = <<SCRIPT
#!/bin/bash

set -eo pipefail

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 1
vm.swappiness=0
EOF
sysctl --system

echo "apt_preserve_sources_list: true" > /etc/cloud/cloud.cfg.d/99-apt-preserve-sources-list.cfg
sed -i 's/\\(archive\\|security\\)\\.ubuntu\\.com/mirrors\\.aliyun\\.com/g' /etc/apt/sources.list
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | apt-key add -
cat > /etc/apt/sources.list.d/docker-ce.list <<EOF
deb http://mirrors.aliyun.com/docker-ce/linux/ubuntu disco stable
EOF
apt-get update && apt-get install -y docker-ce=#{$DOCKER_VER}

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet=#{$KUBE_VER}-00 kubeadm kubectl kubernetes-cni=0.7.5-00

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

# https://github.com/kubernetes/kubernetes/issues/45487
echo 'User=root' >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl enable kubelet && systemctl restart kubelet
systemctl enable docker && systemctl restart docker
usermod -aG docker vagrant
SCRIPT
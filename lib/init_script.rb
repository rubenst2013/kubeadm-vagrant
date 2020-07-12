require_relative 'vars'

$init_script = <<SCRIPT
#!/bin/bash

set -eo pipefail

# Disable swap as kubelet does not like it
swapoff -a
sed -i -E 's/(.*swap.*)/# \1/' /etc/fstab

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_nonlocal_bind = 1
net.ipv4.ip_forward = 1
vm.swappiness=0
EOF
sysctl --system

apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
cat > /etc/apt/sources.list.d/docker-ce.list <<EOF
deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable
EOF
apt-get update && apt-get install -y docker-ce=#{$DOCKER_VER}

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update && apt-get install -y kubelet=#{$KUBE_VER}-00 kubeadm kubectl

cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload
systemctl enable kubelet && systemctl restart kubelet
systemctl enable docker && systemctl restart docker
usermod -aG docker vagrant
SCRIPT
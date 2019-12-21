require_relative 'vars'

$master_script = <<SCRIPT
#!/bin/bash

set -eo pipefail

kubeadm reset -f
kubeadm init --image-repository #{$IMAGE_REPO} \
             --apiserver-advertise-address=#{$MASTER_IP} \
             --apiserver-bind-port=#{$MASTER_PORT} \
             --kubernetes-version v#{$KUBE_VER} \
             --pod-network-cidr=#{$POD_NW_CIDR} \
             --token #{$KUBE_TOKEN} \
             --token-ttl 0 | tee /vagrant/kubeadm.log

mkdir -p $HOME/.kube
sudo cp -Rf /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f /vagrant/kube-flannel.yml
SCRIPT
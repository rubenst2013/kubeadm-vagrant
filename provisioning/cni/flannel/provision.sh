#!/bin/bash -eu

pushd /vagrant/provisioning/cni/flannel/

echo "Provision Flannel Networking"
kubectl apply -f kube-flannel.yaml
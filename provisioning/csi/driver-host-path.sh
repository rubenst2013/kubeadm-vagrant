#!/bin/bash -eu

# Download repo that contains the hostpath csi
cd /home/vagrant/
git clone --branch master --depth 1 https://github.com/kubernetes-csi/csi-driver-host-path.git
cd ./csi-driver-host-path/

# Install for currently installed k8s version
pushd ./deploy/kubernetes-1.18/
./deploy.sh || true
popd

# Add storage class
pushd ./examples
kubectl apply -f csi-storageclass.yaml
popd

# Mark hostpath sc as default
kubectl patch storageclass csi-hostpath-sc -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
#!/bin/bash -eu

cd /home/vagrant/

# Download official git repo for CSI External Snapshotter
git clone https://github.com/kubernetes-csi/external-snapshotter.git --branch master --depth 1
pushd external-snapshotter

# Install Config
kubectl create -f config/crd/

# Install CRDs
kubectl create -f deploy/kubernetes/snapshot-controller/

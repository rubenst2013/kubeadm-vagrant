#!/bin/bash -eu

pushd /vagrant/provisioning/cni/nginx/

helm install nginx-ingress stable/nginx-ingress --version 1.29.2 -f values-nginx.yaml

popd
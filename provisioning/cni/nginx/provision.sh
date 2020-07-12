#!/bin/bash -eu

pushd /vagrant/provisioning/cni/nginx/

helm upgrade --install nginx-ingress stable/nginx-ingress --version 1.40.0 -f values-nginx.yaml

popd
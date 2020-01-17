#!/bin/bash -eu

pushd /vagrant/provisioning/cni/weave/

k8s_servion_info=$(kubectl version | base64 | tr -d '\n')

echo "Provision Weave Net"
curl -sSLo "weave-net.yaml" "https://cloud.weave.works/k8s/net?k8s-version=${k8s_servion_info}"
kubectl apply -f weave-net.yaml

echo "Provision Weaver Scope"
curl -sSLo "weave-scope.yaml" "https://cloud.weave.works/k8s/scope.yaml?k8s-version=${k8s_servion_info}&k8s-service-type=NodePort"
kubectl apply -f weave-scope.yaml
kubectl apply -f weave-scope-app-ingress.yaml
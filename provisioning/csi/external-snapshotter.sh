#!/bin/bash -eu

pushd /home/vagrant/

# Change to the latest supported snapshotter version
SNAPSHOTTER_VERSION=v4.0.0
SNAPSHOTTER_NAMESPACE=kube-system

# Download repo that contains the external snapshotter
git clone --branch "${SNAPSHOTTER_VERSION}" --depth 1 https://github.com/kubernetes-csi/external-snapshotter.git

pushd external-snapshotter/

## install dependencies
apt install -y jq

### Apply VolumeSnapshot CRDs
kubectl apply -f ./client/config/crd/snapshot.storage.k8s.io_volumesnapshotclasses.yaml
kubectl apply -f ./client/config/crd/snapshot.storage.k8s.io_volumesnapshotcontents.yaml
kubectl apply -f ./client/config/crd/snapshot.storage.k8s.io_volumesnapshots.yaml


### Create snapshot controller
kubectl apply -f ./deploy/kubernetes/snapshot-controller/rbac-snapshot-controller.yaml
kubectl apply -f ./deploy/kubernetes/snapshot-controller/setup-snapshot-controller.yaml


### Deploy validating admission webhook for external snapshotter

## Create certificate for the VAW 
./deploy/kubernetes/webhook-example/create-cert.sh --service snapshot-validation-service --secret snapshot-validation-secret --namespace "${SNAPSHOTTER_NAMESPACE}"

## Patch the ValidatingWebhookConfiguration file from the template, filling in the CA bundle field.
cat ./deploy/kubernetes/webhook-example/admission-configuration-template | ./deploy/kubernetes/webhook-example/patch-ca-bundle.sh > ./deploy/kubernetes/webhook-example/admission-configuration.yaml

## Change the namespace in the generated admission-configuration.yaml file. Change the namespace in the service and deployment in the webhook.yaml file.
sed -i "s/  namespace: \"default\"/  namespace: \"${SNAPSHOTTER_NAMESPACE}\"/g" ./deploy/kubernetes/webhook-example/admission-configuration.yaml
sed -i "s/  namespace: default/  namespace: \"${SNAPSHOTTER_NAMESPACE}\"/g" ./deploy/kubernetes/webhook-example/webhook.yaml

## Create the deployment, service and admission configuration objects on the cluster.
kubectl apply -f ./deploy/kubernetes/webhook-example

## Cleanup
popd
rm -R ./external-snapshotter/

popd
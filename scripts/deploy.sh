#!/bin/bash
# Deploy do KubeVirt no minikube com as imagens ppc64le
set -euo pipefail

REGISTRY="${REGISTRY:-192.168.49.1:5000}"
TAG="${TAG:-ppc64le-v1}"
KUBEVIRT_VERSION="v1.8.2"

kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-operator.yaml"
kubectl apply -f "https://github.com/kubevirt/kubevirt/releases/download/${KUBEVIRT_VERSION}/kubevirt-cr.yaml"

sleep 30

kubectl patch kubevirt kubevirt -n kubevirt --type merge \
  -p "{\"spec\":{\"imageTag\":\"${TAG}\"}}"

kubectl delete pods -n kubevirt --all
sleep 30

kubectl label node minikube cpu-model.node.kubevirt.io/POWER9=true --overwrite

kubectl get pods -n kubevirt
kubectl get kubevirt -n kubevirt

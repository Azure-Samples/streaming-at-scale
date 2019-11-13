#!/bin/bash

echo 'Creating kubectl namespace'

# following the repo instructions, this deploys the operator with helm
if ! kubectl --context $AKS_CLUSTER get namespace kafka; then
  kubectl --context $AKS_CLUSTER create namespace kafka
fi
helm repo add strimzi http://strimzi.io/charts/

#"helm upgrade --install" is the idempotent version of "helm install --name"
helm --kube-context $AKS_CLUSTER upgrade --install --namespace kafka kafka-operator strimzi/strimzi-kafka-operator

echo 'Creating kafka inside kubernetes'

helm --kube-context $AKS_CLUSTER upgrade --install --namespace kafka kafka-cluster ../components/azure-kubernetes-service/helm/strimzi-kafka-cluster/

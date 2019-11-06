#!/bin/bash

AKS_CLUSTER_NAME='test-cluster'
RESOURCE_GROUP='test-cluster'
NODE_COUNT='3'
VM_SIZE='Standard_DS2_v2'

# creating aks cluster
az aks create -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP --node-count $NODE_COUNT --node-vm-size $VM_SIZE

# get credentials for kubernetes
az aks get-credentials -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP

# installing helm inside cluster
helm init

# fixing authorizations for tiller inside aks
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

# following the repo instructions, this deploys the operator with helm
kubectl create namespace kafka
helm repo add strimzi http://strimzi.io/charts/
helm install strimzi/strimzi-kafka-operator --namespace kafka --name kafka-operator

# clone the repo in order to deploy kafka on aks
git clone https://github.com/cnadolny/azure-kafka-kubernetes.git

# installing all the yaml files from the repo inside aks
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/tls-kafka.yaml
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/kafka-topics.yaml
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/kafka-users.yaml
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/kafkaclient.yaml

# Cleaning up local resources we downloaded
rm -rf azure-kafka-kubernetes
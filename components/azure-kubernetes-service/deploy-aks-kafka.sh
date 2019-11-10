#!/bin/bash

echo 'Creating kubectl namespace'

# following the repo instructions, this deploys the operator with helm
kubectl create namespace kafka
helm repo add strimzi http://strimzi.io/charts/
helm install strimzi/strimzi-kafka-operator --namespace kafka --name kafka-operator

echo 'Creating kafka inside kubernetes'

# installing all the yaml files from the repo inside aks
kubectl create -n kafka -f ../components/azure-kubernetes-service/simple-kafka.yaml
kubectl create -n kafka -f ../components/azure-kubernetes-service/kafka-topics.yaml

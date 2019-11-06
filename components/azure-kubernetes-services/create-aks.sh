#!/bin/bash

echo 'Creating aks cluster'

# creating aks cluster
az aks create --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP --node-count $NODE_COUNT --node-vm-size $VM_SIZE --generate-ssh-keys --service-principal $SERVICE_PRINCIPAL --client-secret $SERVICE_PRINCIPAL_SECRET

echo 'Getting credentials'

# get credentials for kubernetes
az aks get-credentials -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP

echo 'Initing helm inside the cluster'

# installing helm inside cluster
helm init

echo 'Fixing permission problems for tiller'

# fixing authorizations for tiller inside aks
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

echo 'Creating kubectl namespace'

# following the repo instructions, this deploys the operator with helm
kubectl create namespace kafka
helm repo add strimzi http://strimzi.io/charts/
helm install strimzi/strimzi-kafka-operator --namespace kafka --name kafka-operator

# clone the repo in order to deploy kafka on aks
git clone https://github.com/cnadolny/azure-kafka-kubernetes.git

echo 'Creating kafka inside kubernetes'

# installing all the yaml files from the repo inside aks
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/tls-kafka.yaml
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/kafka-topics.yaml
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/kafka-users.yaml
kubectl create -n kafka -f azure-kafka-kubernetes/kafka-operator-strimzi/kafkaclient.yaml

# Cleaning up local resources we downloaded
rm -rf azure-kafka-kubernetes

# finish all the steps
echo 'Done creating kafka inside aks'
#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating AKS cluster, if not already existing'
echo ". name: $AKS_CLUSTER"

if ! az aks show --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
  echo "getting Subnet ID"
  subnet_id=$(az network vnet subnet show -g $RESOURCE_GROUP -n streaming-subnet --vnet-name $VNET_NAME --query id -o tsv)

  echo "getting Service Principal ID and password"
  appId=$(az keyvault secret show --vault-name $SERVICE_PRINCIPAL_KEYVAULT -n $SERVICE_PRINCIPAL_KV_NAME-id --query value -o tsv)
  password=$(az keyvault secret show --vault-name $SERVICE_PRINCIPAL_KEYVAULT -n $SERVICE_PRINCIPAL_KV_NAME-password --query value -o tsv)

  echo 'creating AKS cluster'
  echo ". name: $AKS_CLUSTER"
  az aks create --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP \
    --node-count $AKS_NODES -s $AKS_VM_SIZE \
    -k $AKS_KUBERNETES_VERSION \
    --generate-ssh-keys \
    --service-principal $appId --client-secret $password \
    --vnet-subnet-id $subnet_id \
    --network-plugin kubenet \
    --enable-addons monitoring \
    --service-cidr 192.168.0.0/16 \
    --dns-service-ip 192.168.0.10 \
    --pod-cidr 10.244.0.0/16 \
    --docker-bridge-address 172.17.0.1/16 \
    -o tsv >> log.txt
fi
az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --overwrite-existing

# Get the id of the service principal configured for AKS
AKS_CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query "servicePrincipalProfile.clientId" --output tsv)

echo 'deploying Helm'

kubectl apply -f ../../components/azure-kubernetes-service/helm-rbac.yaml
helm init --service-account tiller --wait

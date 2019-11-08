#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating ACR instance'
echo ". name: $ACR_NAME"

az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Basic -o tsv >> log.txt

echo 'creating AKS cluster, if not already existing'
echo ". name: $AKS_CLUSTER"

if ! az aks show --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
  echo "getting Subnet ID"
  subnet_id=$(az network vnet subnet show -g $RESOURCE_GROUP -n streaming-subnet --vnet-name $VNET_NAME --query id -o tsv)

  echo "getting Service Principal ID and password"
  appId=$(az keyvault secret show --vault-name $SERVICE_PRINCIPAL_KEYVAULT -n $SERVICE_PRINCIPAL_KV_NAME-id --query value -o tsv)
  password=$(az keyvault secret show --vault-name $SERVICE_PRINCIPAL_KEYVAULT -n $SERVICE_PRINCIPAL_KV_NAME-password --query value -o tsv)

  analytics_ws_resourceId=$(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $LOG_ANALYTICS_WORKSPACE --query id -o tsv)

set -x
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
    --workspace-resource-id $analytics_ws_resourceId \
    -o tsv >> log.txt
fi
az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --overwrite-existing

# Get the id of the service principal configured for AKS
AKS_CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)

# Create role assignment
existing_role=$(az role assignment list --assignee $AKS_CLIENT_ID --role acrpull --scope $ACR_ID -o tsv)
if [ -z "$existing_role" ]; then
  echo 'assign role to SP for ACR pull'
  az role assignment create --assignee $AKS_CLIENT_ID --role acrpull --scope $ACR_ID -o tsv >> log.txt
fi

echo 'building flink-service-port-patcher docker image'
az acr build --registry $ACR_NAME --resource-group $RESOURCE_GROUP \
  --image $ACR_NAME.azurecr.io/flink-service-port-patcher:latest \
  docker/flink-service-port-patcher

echo 'deploying Helm'

kubectl apply -f k8s/helm-rbac.yaml
kubectl apply -f k8s/azure-file-storage-class.yaml
helm init --service-account tiller --wait

echo '. chart: zookeeper'
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm upgrade --install zookeeper incubator/zookeeper


function deploy_helm() {

release_name="flink-$1"
echo ". release: $release_name"

echo 'building flink job image'
tmpdir=$(mktemp -d)
cp -R docker/flink-job $tmpdir
cp ../flink-kafka-consumer/target/assembly/flink-kafka-consumer-$1.jar $tmpdir/flink-job
az acr build --registry $ACR_NAME --resource-group $RESOURCE_GROUP \
  --image $ACR_NAME.azurecr.io/flink-job-$1:$IMAGE_TAG \
  --build-arg job_jar=flink-kafka-consumer-$1.jar \
  --build-arg flink_version=$FLINK_VERSION \
  $tmpdir/flink-job
rm -r $tmpdir

#"helm upgrade --install" is the idempotent version of "helm install --name"
helm upgrade --install --recreate-pods "$release_name" helm/flink-standalone \
  --set service.type=LoadBalancer \
  --set image=$ACR_NAME.azurecr.io/flink-job-$1 \
  --set imageTag=$IMAGE_TAG \
  --set resources.jobmanager.serviceportpatcher.image=$ACR_NAME.azurecr.io/flink-service-port-patcher:latest \
  --set flink.num_taskmanagers=$FLINK_PARALLELISM \
  --set persistence.storageClass=azure-file \
  --set flink.secrets.KAFKA_IN_LISTEN_JAAS_CONFIG="$KAFKA_IN_LISTEN_JAAS_CONFIG" \
  --set flink.secrets.KAFKA_OUT_SEND_JAAS_CONFIG="$KAFKA_OUT_SEND_JAAS_CONFIG" \
  --set flink.secrets.APPINSIGHTS_INSTRUMENTATIONKEY="$APPINSIGHTS_INSTRUMENTATIONKEY" \
  --set resources.jobmanager.args="{--parallelism , $FLINK_PARALLELISM , $2}"

echo "To get the Flink Job manager UI, run:"
echo "  kubectl get services "$release_name-flink-jobmanager" -o '"'jsonpath={"http://"}{.status.loadBalancer.ingress[0].ip}{":8081/\n"}'"'"
echo "It may take some time for the public IP to be assigned by the cloud provisioner."
echo
}


deploy_helm "$FLINK_JOBTYPE" "--kafka.in.topic , \"$KAFKA_TOPIC\" , --kafka.in.bootstrap.servers , \"$KAFKA_IN_LISTEN_BROKERS\" , --kafka.in.request.timeout.ms , \"15000\" , --kafka.in.sasl.mechanism , $KAFKA_IN_LISTEN_SASL_MECHANISM , --kafka.in.security.protocol , $KAFKA_IN_LISTEN_SECURITY_PROTOCOL , --kafka.in.sasl.jaas.config , '\$(KAFKA_IN_LISTEN_JAAS_CONFIG)' , --kafka.out.topic , \"$KAFKA_OUT_TOPIC\" , --kafka.out.bootstrap.servers , \"$KAFKA_OUT_SEND_BROKERS\" , --kafka.out.request.timeout.ms , \"15000\" , --kafka.out.sasl.mechanism , $KAFKA_OUT_SEND_SASL_MECHANISM , --kafka.out.security.protocol , $KAFKA_OUT_SEND_SECURITY_PROTOCOL , --kafka.out.sasl.jaas.config , '\$(KAFKA_OUT_SEND_JAAS_CONFIG)'"

echo "- To list deployed pods, run:"
echo "    kubectl get pods"

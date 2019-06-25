#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting EH primary connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)

echo 'creating ACR instance'
echo ". name: $ACR_NAME"

az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Basic -o tsv >> log.txt
az acr login --name $ACR_NAME

echo 'creating AKS cluster'
echo ". name: $AKS_CLUSTER"

if ! az aks show --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP >/dev/null 2>&1; then
az aks create --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --node-count $AKS_NODES -s $AKS_VM_SIZE -k $AKS_KUBERNETES_VERSION --generate-ssh-keys -o tsv >> log.txt
fi
az aks get-credentials --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --overwrite-existing

# Get the id of the service principal configured for AKS
AKS_CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)

# Create role assignment
existing_role=$(az role assignment list --assignee $AKS_CLIENT_ID --role acrpull --scope $ACR_ID -o tsv)
if [ -z "$existing_role" ]; then
  az role assignment create --assignee $AKS_CLIENT_ID --role acrpull --scope $ACR_ID -o tsv >> log.txt
fi

echo 'building flink job'
mvn -f flink-kafka-consumer clean package

echo 'building flink-service-port-patcher docker image'
docker build -t $ACR_NAME.azurecr.io/flink-service-port-patcher:latest -f docker/flink-service-port-patcher/Dockerfile docker/flink-service-port-patcher
docker push $ACR_NAME.azurecr.io/flink-service-port-patcher:latest

echo 'deploying Helm'

kubectl apply -f k8s/helm-rbac.yaml
kubectl apply -f k8s/azure-file-storage-class.yaml
helm init --service-account tiller --wait

echo '. chart: zookeeper'
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm upgrade --install zookeeper incubator/zookeeper

kafka_conn_args="--kafka.bootstrap.servers , \"$EVENTHUB_NAMESPACE.servicebus.windows.net:9093\" , --kafka.group.id , \"$EVENTHUB_CG\" , --kafka.request.timeout.ms , \"15000\" , --kafka.sasl.mechanism , PLAIN , --kafka.security.protocol , SASL_SSL , --kafka.sasl.jaas.config , '\$(KAFKA_CS)'"

function deploy_helm() {

release_name="flink-$1"
echo ". release: $release_name"

echo 'building flink job image'
docker build -t $ACR_NAME.azurecr.io/flink-job-$1:latest -f docker/flink-job/Dockerfile . --build-arg job_jar=flink-kafka-consumer/target/assembly/flink-kafka-consumer-$1.jar

docker push $ACR_NAME.azurecr.io/flink-job-$1:latest

#"helm upgrade --install" is the idempotent version of "helm install --name"
helm upgrade --install --recreate-pods "$release_name" helm/flink-standalone \
  --set service.type=LoadBalancer \
  --set image=$ACR_NAME.azurecr.io/flink-job-$1 \
  --set imageTag=latest \
  --set resources.jobmanager.serviceportpatcher.image=$ACR_NAME.azurecr.io/flink-service-port-patcher:latest \
  --set flink.num_taskmanagers=$FLINK_PARALLELISM \
  --set persistence.storageClass=azure-file \
  --set flink.secrets.KAFKA_CS="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS\";" \
  --set resources.jobmanager.args="{--parallelism , $FLINK_PARALLELISM , $kafka_conn_args , $2}"

echo "To get the Flink Job manager UI, run:"
echo "  kubectl get services "$release_name-flink-standalone-jobmanager" -o 'jsonpath={"http://"}{.status.loadBalancer.ingress[0].ip}{":8081/"}'"
echo "It may take some time for the public IP to be assigned by the cloud provisioner."
echo
}

deploy_helm "stateful-relay" "--kafka.topic.in , \"$EVENTHUB_NAME\", --kafka.topic.out , \"$EVENTHUB_NAME_OUT\""
deploy_helm "consistency-checker" "--kafka.topic , \"$EVENTHUB_NAME_OUT\""

echo "- To list deployed pods, run:"
echo "    kubectl get pods"
echo "- To view message throughput per Task Manager, run:"
echo "    kubectl logs -l release=flink-consistency-checker,component=taskmanager -c flink"
echo "  you should see lines similar to '1> [2019-06-16T07:25:13Z] 956 events/s, avg end-to-end latency 661 ms; 0 non-sequential events []', with the task number and events ingested per second."

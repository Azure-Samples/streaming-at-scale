#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting EH primary connection string'
EVENTHUB_CS_IN_LISTEN=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Listen --query "primaryConnectionString" -o tsv)
EVENTHUB_CS_OUT_SEND=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Send --query "primaryConnectionString" -o tsv)
EVENTHUB_CS_OUT_LISTEN=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Listen --query "primaryConnectionString" -o tsv)

echo 'creating ACR instance'
echo ". name: $ACR_NAME"

az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Basic -o tsv >> log.txt

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
cp flink-kafka-consumer/target/assembly/flink-kafka-consumer-$1.jar $tmpdir/flink-job
az acr build --registry $ACR_NAME --resource-group $RESOURCE_GROUP \
  --image $ACR_NAME.azurecr.io/flink-job-$1:latest \
  --build-arg job_jar=flink-kafka-consumer-$1.jar \
  $tmpdir/flink-job
rm -r $tmpdir

#"helm upgrade --install" is the idempotent version of "helm install --name"
helm upgrade --install --recreate-pods "$release_name" helm/flink-standalone \
  --set service.type=LoadBalancer \
  --set image=$ACR_NAME.azurecr.io/flink-job-$1 \
  --set imageTag=latest \
  --set resources.jobmanager.serviceportpatcher.image=$ACR_NAME.azurecr.io/flink-service-port-patcher:latest \
  --set flink.num_taskmanagers=$FLINK_PARALLELISM \
  --set persistence.storageClass=azure-file \
  --set flink.secrets.KAFKA_CS_IN_LISTEN="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS_IN_LISTEN\";" \
  --set flink.secrets.KAFKA_CS_OUT_SEND="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS_OUT_SEND\";" \
  --set flink.secrets.KAFKA_CS_OUT_LISTEN="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS_OUT_LISTEN\";" \
  --set resources.jobmanager.args="{--parallelism , $FLINK_PARALLELISM , $2}"

echo "To get the Flink Job manager UI, run:"
echo "  kubectl get services "$release_name-flink-standalone-jobmanager" -o 'jsonpath={"http://"}{.status.loadBalancer.ingress[0].ip}{":8081/"}'"
echo "It may take some time for the public IP to be assigned by the cloud provisioner."
echo
}

deploy_helm "stateful-relay" "--kafka.in.topic , \"$EVENTHUB_NAME\" , --kafka.in.bootstrap.servers , \"$EVENTHUB_NAMESPACE.servicebus.windows.net:9093\" , --kafka.in.request.timeout.ms , \"15000\" , --kafka.in.sasl.mechanism , PLAIN , --kafka.in.security.protocol , SASL_SSL , --kafka.in.sasl.jaas.config , '\$(KAFKA_CS_IN_LISTEN)' , --kafka.out.topic , \"$EVENTHUB_NAME\" , --kafka.out.bootstrap.servers , \"$EVENTHUB_NAMESPACE.servicebus.windows.net:9093\" , --kafka.out.request.timeout.ms , \"15000\" , --kafka.out.sasl.mechanism , PLAIN , --kafka.out.security.protocol , SASL_SSL , --kafka.out.sasl.jaas.config , '\$(KAFKA_CS_OUT_SEND)'"
deploy_helm "consistency-checker" "--kafka.in.topic , \"$EVENTHUB_NAME\" , --kafka.in.bootstrap.servers , \"$EVENTHUB_NAMESPACE_OUT.servicebus.windows.net:9093\" , --kafka.in.request.timeout.ms , \"15000\" , --kafka.in.sasl.mechanism , PLAIN , --kafka.in.security.protocol , SASL_SSL , --kafka.in.sasl.jaas.config , '\$(KAFKA_CS_OUT_LISTEN)'"

echo "- To list deployed pods, run:"
echo "    kubectl get pods"
echo "- To view message throughput per Task Manager, run:"
echo "    kubectl logs -l release=flink-consistency-checker,component=taskmanager -c flink"
echo "  you should see lines similar to '1> [2019-06-16T07:25:13Z] 956 events/s, avg end-to-end latency 661 ms; 0 non-sequential events []', with the task number and events ingested per second."

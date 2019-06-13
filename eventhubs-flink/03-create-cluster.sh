#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting EH primary connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)

echo 'getting storage key'
AZURE_STORAGE_KEY=$(az storage account keys list -n $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP --query '[0].value' -o tsv)

echo 'creating share'
az storage share create --account-name $AZURE_STORAGE_ACCOUNT -n "flinkshare" -o tsv >> log.txt

echo 'creating ACR instance'
echo ". name: $ACR_NAME"

az acr create --name $ACR_NAME --resource-group $RESOURCE_GROUP --sku Basic -o tsv >> log.txt
az acr login --name $ACR_NAME

echo 'creating AKS cluster'
echo ". name: $AKS_CLUSTER"

#az aks create --name $AKS_CLUSTER --resource-group $RESOURCE_GROUP --node-count $AKS_NODES --generate-ssh-keys -o tsv >> log.txt
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

echo 'building image'
mvn -f flink-kafka-consumer package
docker build -t $ACR_NAME.azurecr.io/flinkjob:latest -f docker/Dockerfile . --build-arg job_jar=flink-kafka-consumer/target/flink-sample-kafka-job-0.0.1-SNAPSHOT.jar 
docker push $ACR_NAME.azurecr.io/flinkjob:latest

echo 'deploying Helm'
echo ". chart: $AKS_HELM_CHART"

kubectl apply -f helm/helm-rbac.yaml
helm init --service-account tiller --wait

helm_config_tempfile=$(mktemp)
cat > "$helm_config_tempfile" <<EOF
resources:
  jobmanager:
    args:
      - --parallelism
      - $FLINK_PARALLELISM
      - --kafka.bootstrap.servers
      - "$EVENTHUB_NAMESPACE.servicebus.windows.net:9093"
      - --kafka.group.id
      - "$EVENTHUB_CG"
      - --kafka.request.timeout.ms
      - "15000"
      - --kafka.sasl.mechanism
      - PLAIN
      - --kafka.security.protocol
      - SASL_SSL
      - --kafka.sasl.jaas.config
      - 'org.apache.kafka.common.security.plain.PlainLoginModule required username="\$ConnectionString" password="$EVENTHUB_CS";'
      - --kafka.topic
      - "$EVENTHUB_NAME"
EOF

#"helm upgrade --install" is the idempotent version of "helm install --name"
#helm status "$AKS_HELM_CHART" -o json | jq .info.status.code) == 1|DEPLOYED
helm upgrade --install "$AKS_HELM_CHART" helm/flink-standalone \
  --set service.type=LoadBalancer \
  --set image=$ACR_NAME.azurecr.io/flinkjob \
  --set imageTag=latest \
  --set flink.num_taskmanagers=$FLINK_PARALLELISM \
  --set fileshare.share=flinkshare \
  --set fileshare.accountname=$AZURE_STORAGE_ACCOUNT \
  --set fileshare.accountkey=$AZURE_STORAGE_KEY \
  -f "$helm_config_tempfile"

#rm $helm_config_tempfile

echo 'Waiting for Flink Job Manager public IP to be assigned'
FLINK_JOBMAN_IP=
while [ -z "$FLINK_JOBMAN_IP" ]; do
  echo -n "."
  FLINK_JOBMAN_IP=$(kubectl get services "$AKS_HELM_CHART-flink-standalone-jobmanager" -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
  sleep 5
done
echo
echo "Flink Job manager UI: http://$FLINK_JOBMAN_IP:8081/"
echo "- To list deployed pods, run:"
echo "    kubectl get pods"
echo "- To view message throughput per Task Manager, run:"
echo "    kubectl logs --tail=10 --follow flink-flink-taskmanager-xxxxx-xxxxx"
echo "  (using the name of one of the taskmanager pods from the 'get pods' command)"
echo "  you should see lines similar to '1> 11157', with the task number and count of events ingested per second."

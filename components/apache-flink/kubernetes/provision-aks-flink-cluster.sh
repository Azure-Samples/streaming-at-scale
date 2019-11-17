#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Get the Application insights key
APPINSIGHTS_INSTRUMENTATIONKEY=$(az monitor app-insights component show --app $APPINSIGHTS_NAME -g $RESOURCE_GROUP --query instrumentationKey -o tsv)

echo 'building flink-service-port-patcher docker image'
az acr build --registry $ACR_NAME --resource-group $RESOURCE_GROUP \
  --image $ACR_NAME.azurecr.io/flink-service-port-patcher:latest \
  docker/flink-service-port-patcher

echo 'deploying storage class'

kubectl --context $AKS_CLUSTER apply -f k8s/azure-file-storage-class.yaml

echo 'deploying Helm charts'

echo '. chart: zookeeper'
helm --kube-context $AKS_CLUSTER repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm --kube-context $AKS_CLUSTER upgrade --install zookeeper incubator/zookeeper

release_name="flink-$FLINK_JOBTYPE"
echo ". release: $release_name"

echo 'building flink job image'
tmpdir=$(mktemp -d)
cp -R docker/flink-job $tmpdir
cp ../flink-kafka-consumer/target/assembly/flink-kafka-consumer-$FLINK_JOBTYPE.jar $tmpdir/flink-job
az acr build --registry $ACR_NAME --resource-group $RESOURCE_GROUP \
  --image $ACR_NAME.azurecr.io/flink-job-$FLINK_JOBTYPE:$IMAGE_TAG \
  --build-arg job_jar=flink-kafka-consumer-$FLINK_JOBTYPE.jar \
  --build-arg flink_version=$FLINK_VERSION \
  $tmpdir/flink-job
rm -r $tmpdir

#"helm upgrade --install" is the idempotent version of "helm install --name"
helm --kube-context $AKS_CLUSTER upgrade --install --recreate-pods "$release_name" helm/flink-standalone \
  --set service.type=LoadBalancer \
  --set image=$ACR_NAME.azurecr.io/flink-job-$FLINK_JOBTYPE \
  --set imageTag=$IMAGE_TAG \
  --set resources.jobmanager.serviceportpatcher.image=$ACR_NAME.azurecr.io/flink-service-port-patcher:latest \
  --set flink.num_taskmanagers=$FLINK_PARALLELISM \
  --set persistence.storageClass=azure-file \
  --set flink.secrets.KAFKA_IN_LISTEN_JAAS_CONFIG="$KAFKA_IN_LISTEN_JAAS_CONFIG" \
  --set flink.secrets.KAFKA_OUT_SEND_JAAS_CONFIG="$KAFKA_OUT_SEND_JAAS_CONFIG" \
  --set flink.secrets.APPINSIGHTS_INSTRUMENTATIONKEY="$APPINSIGHTS_INSTRUMENTATIONKEY" \
  --set resources.jobmanager.args="{--parallelism , $FLINK_PARALLELISM , --kafka.in.topic , \"$KAFKA_TOPIC\" , --kafka.in.bootstrap.servers , \"$KAFKA_IN_LISTEN_BROKERS\" , --kafka.in.request.timeout.ms , \"15000\" , --kafka.in.sasl.mechanism , $KAFKA_IN_LISTEN_SASL_MECHANISM , --kafka.in.security.protocol , $KAFKA_IN_LISTEN_SECURITY_PROTOCOL , --kafka.in.sasl.jaas.config , '\$(KAFKA_IN_LISTEN_JAAS_CONFIG)' , --kafka.out.topic , \"$KAFKA_OUT_TOPIC\" , --kafka.out.bootstrap.servers , \"$KAFKA_OUT_SEND_BROKERS\" , --kafka.out.request.timeout.ms , \"15000\" , --kafka.out.sasl.mechanism , $KAFKA_OUT_SEND_SASL_MECHANISM , --kafka.out.security.protocol , $KAFKA_OUT_SEND_SECURITY_PROTOCOL , --kafka.out.sasl.jaas.config , '\$(KAFKA_OUT_SEND_JAAS_CONFIG)' }"

echo "To get the Flink Job manager UI, run:"
echo "  kubectl --context $AKS_CLUSTER get services "$release_name-flink-jobmanager" -o '"'jsonpath={"http://"}{.status.loadBalancer.ingress[0].ip}{":8081/\n"}'"'"
echo "It may take some time for the public IP to be assigned by the cloud provisioner."
echo

echo "- To list deployed pods, run:"
echo "    kubectl --context $AKS_CLUSTER get pods"

#!/bin/bash

set -euo pipefail

echo 'creating HDInsight cluster'
echo ". name: $HDINSIGHT_NAME"

config=$(cat<<JSON
{
  "kafka-broker": {
    "auto.create.topics.enable": "true",
    "num.partitions": "$KAFKA_PARTITIONS"
  }
}
JSON
)

az hdinsight create -t kafka -g $RESOURCE_GROUP -n $HDINSIGHT_NAME \
  -p "$HDINSIGHT_PASSWORD" \
  --version 3.6 --component-version Kafka=1.1 \
  --headnode-size Standard_D3_V2 \
  --zookeepernode-size Standard_A2_V2 \
  --workernode-size $HDINSIGHT_WORKER_SIZE --size $HDINSIGHT_WORKERS \
  --workernode-data-disks-per-node 2 \
  --vnet-name $VNET_NAME --subnet ingestion-subnet \
  --cluster-configurations "$config" \
  --storage-account $AZURE_STORAGE_ACCOUNT \
  -o tsv >> log.txt

endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

kafka_config_changed=""

echo 'checking Kafka IP advertising status'
kafka_env_tag=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" "https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME?fields=Clusters/desired_configs" | jq -r '.Clusters.desired_configs."kafka-env".tag')
if [ "$kafka_env_tag" != "IP_ADV" ]; then
  echo 'Enabling Kafka IP advertising'
  curl -fsS -u admin:"$HDINSIGHT_PASSWORD" "https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/configurations?type=kafka-env&tag=$kafka_env_tag" | jq '[{"Clusters": {"desired_config": [.items[0] | .tag="IP_ADV" | .service_config_version_note="IP Advertising" | .properties.content += "\n# Configure Kafka to advertise IP addresses instead of FQDN\nIP_ADDRESS=$(hostname -i)\necho advertised.listeners=$IP_ADDRESS\nsed -i.bak -e \"/advertised/{/advertised@/!d;}\" /usr/hdp/current/kafka-broker/conf/server.properties\necho \"advertised.listeners=PLAINTEXT://$IP_ADDRESS:9092\" >> /usr/hdp/current/kafka-broker/conf/server.properties\n"] } } ]'  | curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -X PUT -H 'X-Requested-By: ambari' -d@- https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME >> log.txt
 kafka_config_changed=1
fi

echo 'checking Kafka IP listening addresses'
kafka_broker_tag=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" "https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME?fields=Clusters/desired_configs" | jq -r '.Clusters.desired_configs."kafka-broker".tag')
if [ "$kafka_broker_tag" != "IP_ADV" ]; then
  echo 'Enabling Kafka IP listening on all interfaces'
  curl -fsS -u admin:"$HDINSIGHT_PASSWORD" "https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/configurations?type=kafka-broker&tag=$kafka_broker_tag" | jq '[{"Clusters": {"desired_config": [.items[0] | .tag="IP_ADV" | .service_config_version_note="IP Advertising" | .properties.listeners = "PLAINTEXT://0.0.0.0:9092" ] } } ]'  | curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -X PUT -H 'X-Requested-By: ambari' -d@- https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME >> log.txt
 kafka_config_changed=1
fi

if [ -n "$kafka_config_changed" ]; then
  echo 'Stopping Kafka service'
  curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -H 'X-Requested-By: ambari' -X PUT -d '{"Body": {"ServiceInfo": {"state": "INSTALLED"}}}' https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/services/KAFKA >> log.txt
  TIMEOUT=600
  for i in $(seq 1 $TIMEOUT); do
    if [ "$(curl -fsS -u admin:$HDINSIGHT_PASSWORD https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/services/KAFKA | jq -r .ServiceInfo.state)" == "INSTALLED" ]; then
      break
    fi
    sleep 1
  done
  echo 'Starting Kafka service'
  curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -H 'X-Requested-By: ambari' -X PUT -d '{"Body": {"ServiceInfo": {"state": "STARTED"}}}' https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/services/KAFKA >> log.txt
fi

echo 'Enable HDInsight monitoring'
echo ". workspace: $LOG_ANALYTICS_WORKSPACE"

az hdinsight monitor enable -g $RESOURCE_GROUP -n $HDINSIGHT_NAME --workspace $LOG_ANALYTICS_WORKSPACE \
  -o tsv >> log.txt

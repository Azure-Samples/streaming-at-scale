#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

CONTAINER_REGISTRY=$PREFIX"acr"
EVENTS_PER_SECOND="$(($TESTTYPE * 1000))"

echo "creating container registry..."
az acr create -g $RESOURCE_GROUP -n $CONTAINER_REGISTRY --sku Basic --admin-enabled true \
    -o tsv >> log.txt
REGISTRY_LOGIN_SERVER=$(az acr show -n $CONTAINER_REGISTRY --query loginServer -o tsv)
REGISTRY_LOGIN_PASS=$(az acr credential show -n $CONTAINER_REGISTRY --query passwords[0].value -o tsv)

echo "building generator container..."
az acr build --registry $CONTAINER_REGISTRY --image generator:latest ../simulator/generator \
    -o tsv >> log.txt

echo "getting HDInsight Ambari endpoint..."
endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

echo "reading Kafka Broker IPs from HDInsight Ambari..."
endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')
kafka_hostnames=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -G https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name)"] | join(" ")')
# Convert Kafka broker hostnames to IP addresses, since ACI doesn't support internal name resolution currently
# (https://docs.microsoft.com/en-us/azure/container-instances/container-instances-vnet#unsupported-networking-scenarios)
kafka_brokers=""
for host in $kafka_hostnames; do
    host_ip=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -G https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/hosts/$host | jq -r .Hosts.ip)
    kafka_brokers="$kafka_brokers,$host_ip:9092"
done
#remove initial comma from string
kafka_brokers=${kafka_brokers:1}

echo "creating generator container instance..."
az container delete -g $RESOURCE_GROUP -n data-generator --yes \
    -o tsv >> log.txt 2>/dev/null
az container create -g $RESOURCE_GROUP -n data-generator \
    --image $REGISTRY_LOGIN_SERVER/generator:latest \
    --vnet $VNET_NAME --subnet producers-subnet \
    --registry-login-server $REGISTRY_LOGIN_SERVER \
    --registry-username $CONTAINER_REGISTRY --registry-password "$REGISTRY_LOGIN_PASS" \
    -e \
      KAFKA_SERVERS="$kafka_brokers" \
      KAFKA_TOPIC="streaming" \
      EVENTS_PER_SECOND="$EVENTS_PER_SECOND" \
      DUPLICATE_EVERY_N_EVENTS="${SIMULATOR_DUPLICATE_EVERY_N_EVENTS:-1000}" \
      SPARK_JARS=/sparklib/spark-sql-kafka-0-10_2.11-2.4.3.jar,/sparklib/kafka-clients-0.10.2.2.jar \
      COMPLEX_DATA_COUNT=7 \
    --cpu 2 --memory 2 \
    -o tsv >> log.txt

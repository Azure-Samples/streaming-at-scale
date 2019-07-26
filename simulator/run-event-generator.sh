#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

CONTAINER_REGISTRY=$PREFIX"acr"

az acr create -g $RESOURCE_GROUP -n $CONTAINER_REGISTRY --sku Basic --admin-enabled true

az acr build --registry $CONTAINER_REGISTRY --image generator:latest ../simulator/generator

endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

kafka_hostnames=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -G https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name)"] | join(" ")')
echo $kafka_hostnames
kafka_brokers=""
for host in $kafka_hostnames; do
    host_ip=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -G https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/hosts/$host | jq -r .Hosts.ip)
    kafka_brokers="$kafka_brokers,$host_ip:9092"
done
kafka_brokers=${kafka_brokers:1}

REGISTRY_LOGIN_SERVER=$(az acr show -n $CONTAINER_REGISTRY --query loginServer -o tsv)
REGISTRY_LOGIN_PASS=$(az acr credential show -n $CONTAINER_REGISTRY --query passwords[0].value -o tsv)

echo "creating generator container..."
az container create -g $RESOURCE_GROUP -n data-generator \
    --image $REGISTRY_LOGIN_SERVER/generator:latest \
    --vnet $VNET_NAME --subnet producers-subnet \
    --registry-login-server $REGISTRY_LOGIN_SERVER \
    --registry-username $CONTAINER_REGISTRY --registry-password "$REGISTRY_LOGIN_PASS" \
    -e KAFKA_SERVERS="$kafka_brokers" KAFKA_TOPIC="streaming" DUPLICATE_EVERY_N_EVENTS="${SIMULATOR_DUPLICATE_EVERY_N_EVENTS:-1000}" \
    SPARK_JARS=/sparklib/spark-sql-kafka-0-10_2.11-2.4.3.jar,/sparklib/kafka-clients-0.10.2.2.jar \
    --cpu 2 --memory 2 \
    -o tsv

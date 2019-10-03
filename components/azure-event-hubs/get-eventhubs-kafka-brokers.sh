#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)

eh_resource=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.EventHub/namespaces -n "$EVENTHUB_NAMESPACE" --query id -o tsv)
export KAFKA_BROKERS="$EVENTHUB_NAMESPACE.servicebus.windows.net:9093"
export KAFKA_SECURITY_PROTOCOL=SASL_SSL
export KAFKA_SASL_MECHANISM=PLAIN
export KAFKA_SASL_JAAS_CONFIG="org.apache.kafka.common.security.plain.PlainLoginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS\";"

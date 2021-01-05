#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

namespace=$1
policy=$2

source ../components/azure-event-hubs/get-eventhubs-connection-string.sh "$namespace" "$policy"

eh_resource=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.EventHub/namespaces -n "$namespace" --query id -o tsv)
export KAFKA_BROKERS="$namespace.servicebus.windows.net:9093"
export KAFKA_SECURITY_PROTOCOL=SASL_SSL
export KAFKA_SASL_MECHANISM=PLAIN
export KAFKA_SASL_USERNAME='$ConnectionString'
export KAFKA_SASL_PASSWORD="$EVENTHUB_CS"

# For running outside of Databricks: org.apache.kafka.common.security.plain.PlainLoginModule
# For running within Databricks: kafkashaded.org.apache.kafka.common.security.plain.PlainLoginModule
loginModule="org.apache.kafka.common.security.plain.PlainLoginModule"
loginModuleDatabricks="kafkashaded.$loginModule"
export KAFKA_SASL_JAAS_CONFIG="$loginModule required username=\"$KAFKA_SASL_USERNAME\" password=\"$KAFKA_SASL_PASSWORD\";"
export KAFKA_SASL_JAAS_CONFIG_DATABRICKS="$loginModuleDatabricks required username=\"$KAFKA_SASL_USERNAME\" password=\"$KAFKA_SASL_PASSWORD\";"

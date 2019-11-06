#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

namespace=$1
policy=$2

EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name "$namespace" --name "$policy" --query "primaryConnectionString" -o tsv)

eh_resource=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.EventHub/namespaces -n "$namespace" --query id -o tsv)
export KAFKA_BROKERS="$namespace.servicebus.windows.net:9093"
export KAFKA_SECURITY_PROTOCOL=SASL_SSL
export KAFKA_SASL_MECHANISM=PLAIN

# For running outside of Databricks: org.apache.kafka.common.security.plain.PlainLoginModule
# For running within Databricks: kafkashaded.org.apache.kafka.common.security.plain.PlainLoginModule
loginModule="org.apache.kafka.common.security.plain.PlainLoginModule"
loginModuleDatabricks="kafkashaded.$loginModule"
export KAFKA_SASL_JAAS_CONFIG="$loginModule required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS\";"
export KAFKA_SASL_JAAS_CONFIG_DATABRICKS="$loginModuleDatabricks required username=\"\$ConnectionString\" password=\"$EVENTHUB_CS\";"

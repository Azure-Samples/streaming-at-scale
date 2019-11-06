#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating azure key vault seret'

echo 'getting EH connection strings'
EVENTHUB_CS_IN_LISTEN=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Listen --query "primaryConnectionString" -o tsv)
EVENTHUB_CS_OUT_SEND=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Send --query "primaryConnectionString" -o tsv)
KAFKA_CS_IN_LISTEN="org.apache.kafka.common.security.plain.PlainLoginModule required username=\\\"\\\$ConnectionString\\\" password=\\\"$EVENTHUB_CS_IN_LISTEN\\\";"
KAFKA_CS_OUT_SEND="org.apache.kafka.common.security.plain.PlainLoginModule required username=\\\"\\\$ConnectionString\\\" password=\\\"$EVENTHUB_CS_OUT_SEND\\\";"

az keyvault secret set --vault-name $AZURE_KEY_VAULT --name "EVENTHUB-CS-IN-LISTEN" --value $EVENTHUB_CS_IN_LISTEN
az keyvault secret set --vault-name $AZURE_KEY_VAULT --name "EVENTHUB-CS-OUT-SEND" --value $EVENTHUB_CS_OUT_SEND


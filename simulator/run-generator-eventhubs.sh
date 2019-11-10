#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Optional variable for protocol used by generator: "eventhubs" (default) or "kafka"
mode=${GENERATOR_MODE:-eventhubs}

if [ "$mode" == "kafka" ]; then

  source ../components/azure-event-hubs/get-eventhubs-kafka-brokers.sh "$EVENTHUB_NAMESPACE" "Send"

  export KAFKA_TOPIC="$EVENTHUB_NAME"
  source ../simulator/run-generator-kafka.sh

  return
fi

echo 'getting Event Hub connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Send --query "primaryConnectionString" -o tsv)

OUTPUT_FORMAT="eventhubs"
OUTPUT_OPTIONS="{}"
SECURE_OUTPUT_OPTIONS="{\"eventhubs.connectionstring\": \"$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME\"}"

source ../simulator/create-generator-instances.sh

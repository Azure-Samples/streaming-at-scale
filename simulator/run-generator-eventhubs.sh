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
source ../components/azure-event-hubs/get-eventhubs-connection-string.sh "$EVENTHUB_NAMESPACE" "Send"

SIMULATOR_VARIABLES=""
SIMULATOR_CONNECTION_SETTING="EventHubConnectionString=$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"

source ../simulator/run-simulator.sh

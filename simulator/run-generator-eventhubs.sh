#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting Event Hub connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Send --query "primaryConnectionString" -o tsv)

OUTPUT_FORMAT="eventhubs"
OUTPUT_OPTIONS="{}"
SECURE_OUTPUT_OPTIONS="{\"eventhubs.connectionstring\": \"$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME\"}"

source ../simulator/create-generator-instances.sh

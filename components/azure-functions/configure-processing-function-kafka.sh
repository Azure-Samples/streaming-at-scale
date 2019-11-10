#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'adding app settings for connection strings'

echo ". Kafka Brokers: $KAFKA_BROKERS"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings KafkaBrokers=$KAFKA_BROKERS \
    -o tsv >> log.txt

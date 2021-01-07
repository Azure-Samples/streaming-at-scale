#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

subscription_name="streaming-at-scale"

echo 'creating storage events queue and Event Grid subscription'
echo ". name: $AZURE_STORAGE_ACCOUNT_GEN2"
echo ". queue: $STORAGE_EVENT_QUEUE"
echo ". subscription: $subscription_name"

echo 'getting storage account ID'
storage_account_id=$(az storage account show --name $AZURE_STORAGE_ACCOUNT_GEN2 -g $RESOURCE_GROUP --query id -o tsv)

az storage queue create \
  --name "$STORAGE_EVENT_QUEUE" \
  --account-name $AZURE_STORAGE_ACCOUNT_GEN2 \
  --only-show-errors \
  -o tsv >>log.txt

storage_id=$(az storage account show --name $AZURE_STORAGE_ACCOUNT_GEN2 --query id -o tsv)

az eventgrid event-subscription create \
  --name "$subscription_name" \
  --source-resource-id "$storage_account_id" \
  --endpoint-type storagequeue \
  --endpoint "$storage_id/queueservices/default/queues/$STORAGE_EVENT_QUEUE" \
  -o tsv >>log.txt

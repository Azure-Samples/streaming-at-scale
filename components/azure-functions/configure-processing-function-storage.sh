#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting storage key'
AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURE_STORAGE_ACCOUNT_GEN2 -g $RESOURCE_GROUP -o tsv)

echo ". StorageConnectionString"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --settings StorageConnectionString=$AZURE_STORAGE_CONNECTION_STRING \
  -o tsv >> log.txt

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating ADLS Gen2 storage account'
echo ". name: $AZURE_STORAGE_ACCOUNT_GEN2"
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file ../components/azure-storage/storage-hfs-arm-template.json \
  --parameters \
  storageAccountName=$AZURE_STORAGE_ACCOUNT_GEN2 \
  -o tsv >>log.txt


#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Default parameters for the call
# Those are kept here to preserve other solutions working with default values.

# Template path
if [ -z "${AZURE_STORAGE_TEMPLATE_PATH-}" ]; then
    AZURE_STORAGE_TEMPLATE_PATH="../components/azure-storage/storage-hfs-arm-template.json"
fi

# Template parameters
if [ -z "${AZURE_STORAGE_TEMPLATE_PARAMS-}" ]; then
    AZURE_STORAGE_TEMPLATE_PARAMS="storageAccountName=$AZURE_STORAGE_ACCOUNT_GEN2"
fi

echo 'creating ADLS Gen2 storage account'
echo ". name: $AZURE_STORAGE_ACCOUNT_GEN2"
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file $AZURE_STORAGE_TEMPLATE_PATH \
  --parameters $AZURE_STORAGE_TEMPLATE_PARAMS \
  -o tsv >>log.txt


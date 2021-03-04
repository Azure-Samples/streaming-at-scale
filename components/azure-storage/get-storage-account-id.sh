#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# Get the ID of the storage account that is the source fo events here
export STORAGEID=$(az storage account show \
      --name $AZURE_STORAGE_ACCOUNT_GEN2 \
      --resource-group $RESOURCE_GROUP \
      --query id --output tsv)
#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating storage account'
echo ". name: $AZURE_STORAGE_ACCOUNT"

az storage account create -n $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP \
    --kind StorageV2 --sku Standard_LRS \
    -o tsv >> log.txt

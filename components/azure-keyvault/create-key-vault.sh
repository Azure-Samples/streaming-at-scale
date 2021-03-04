#!/bin/bash
set -euo pipefail

echo 'creating key vault'
echo "name: $AZURE_KEY_VAULT_NAME"

## Create the key vault with given parameters
az keyvault create \
    -g $RESOURCE_GROUP \
    --name $AZURE_KEY_VAULT_NAME \
    --location $LOCATION \
    -o tsv >> log.txt
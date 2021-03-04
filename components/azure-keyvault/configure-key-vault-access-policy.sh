#!/bin/bash
set -euo pipefail

echo 'setting key vault policy'
echo "name: $AZURE_KEY_VAULT_NAME"

## set the secret setting policy to the wanted service principal
az keyvault set-policy \
    --name $AZURE_KEY_VAULT_NAME \
    --secret-permissions "set" \
    --object-id $AZURE_KEY_VAULT_AAD_OBJECTID \
    -o tsv >> log.txt
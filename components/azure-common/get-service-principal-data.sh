#!/bin/bash

# Get data from key vault into environment variables
set -euo pipefail

echo "Getting service principal data from Key Vault"
export SP_CLIENT_ID=$(az keyvault secret show \
    --vault-name $SERVICE_PRINCIPAL_KEYVAULT \
    --name $SERVICE_PRINCIPAL_KV_NAME-id \
    --query value \
    -o tsv)

export SP_CLIENT_SECRET=$(az keyvault secret show \
    --vault-name $SERVICE_PRINCIPAL_KEYVAULT \
    --name $SERVICE_PRINCIPAL_KV_NAME-password \
    --query value \
    -o tsv)

export SP_CLIENT_OBJECTID=$(az ad sp show --id $SP_CLIENT_ID --query objectId -o tsv)
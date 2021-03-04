#!/bin/bash
set -euo pipefail

echo 'updating key vault secret'
echo "name: $AZURE_KEY_VAULT_NAME"

#build arguments
args=(--resource-group "${RESOURCE_GROUP}" \
    --template-file "${UPDATE_KEYVAULT_SECRET_TEMPLATE_PATH}" \
    --parameters ${UPDATE_KEYVAULT_SECRET_PARAMETERS} \
    --name "UpdateKeyVaultSecretDeployment"
)

# run deployment
az deployment group create "${args[@]}" -o tsv >> log.txt

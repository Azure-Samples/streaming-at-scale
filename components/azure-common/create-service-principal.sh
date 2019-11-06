#!/bin/bash

# Create service principal for consumer clients to read Data Explorer data (used by Databricks verification job).
# Run as early as possible in scripts, as principal takes time to become available for RBAC operations.

set -euo pipefail

echo "checking Key Vault exists"
if ! az keyvault show -g $RESOURCE_GROUP -n $SERVICE_PRINCIPAL_KEYVAULT -o none 2>/dev/null ; then
  echo "creating KeyVault $SERVICE_PRINCIPAL_KEYVAULT"
  az keyvault create -g $RESOURCE_GROUP -n $SERVICE_PRINCIPAL_KEYVAULT -o tsv >>log.txt
fi

echo "checking service principal exists"
if ! az keyvault secret show --vault-name $SERVICE_PRINCIPAL_KEYVAULT --name $SERVICE_PRINCIPAL_KV_NAME-password -o none 2>/dev/null ; then
  # When running in Azure DevOps pipeline (AzureCLI task with "addSpnToEnvironment: true"), use the provided service principal
  if [ -n "${servicePrincipalId:-}" ]; then
    appId="$servicePrincipalId"
    password="$servicePrincipalKey"
  # Otherwise create a new service principal
  else
    echo "creating service principal"
    password=$(az ad sp create-for-rbac \
                  --skip-assignment \
                  --name http://$SERVICE_PRINCIPAL_KV_NAME \
                  --query password \
                  --output tsv)
    echo "getting service principal"
    appId=$(az ad sp show --id http://$SERVICE_PRINCIPAL_KV_NAME --query appId --output tsv)
  fi

  echo "storing service principal in Key Vault"
  az keyvault secret set \
    --vault-name $SERVICE_PRINCIPAL_KEYVAULT \
    --name $SERVICE_PRINCIPAL_KV_NAME-id \
    --value "$appId" \
    -o tsv >>log.txt
  az keyvault secret set \
    --vault-name $SERVICE_PRINCIPAL_KEYVAULT \
    --name $SERVICE_PRINCIPAL_KV_NAME-password \
    --value "$password" \
    -o tsv >>log.txt
fi

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

if [ -n "${DATABRICKS_TOKEN:-}" ]; then

  echo 'Not creating Databricks workspace. Using environment DATABRICKS_TOKEN setting'

  if [ -z "${DATABRICKS_HOST:-}" ]; then
    export DATABRICKS_HOST="https://$LOCATION.azuredatabricks.net"
  fi

else

if ! az resource show -g $RESOURCE_GROUP --resource-type Microsoft.Databricks/workspaces -n $ADB_WORKSPACE -o none 2>/dev/null; then
echo 'creating databricks workspace'
echo ". name: $ADB_WORKSPACE"
az deployment group create \
  --name $ADB_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --template-uri https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/quickstarts/microsoft.databricks/databricks-all-in-one-template-for-vnet-injection/azuredeploy.json \
  --parameters \
  workspaceName=$ADB_WORKSPACE \
  pricingTier=standard \
  -o tsv >>log.txt
fi

databricks_metainfo=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.Databricks/workspaces -n $ADB_WORKSPACE -o json)

# Databricks CLI automatically picks up configuration from $DATABRICKS_HOST and $DATABRICKS_TOKEN.
export DATABRICKS_HOST=$(jq -r '"https://" + .location + ".azuredatabricks.net"' <<<"$databricks_metainfo")

if ! az keyvault show -g $RESOURCE_GROUP -n $ADB_TOKEN_KEYVAULT -o none 2>/dev/null ; then
  echo 'creating Key Vault to store Databricks PAT token'
  az keyvault create -g $RESOURCE_GROUP -n $ADB_TOKEN_KEYVAULT -o tsv >>log.txt
fi

echo 'checking PAT token secret presence in Key Vault'
databricks_token_secret_name="DATABRICKS-TOKEN"
pat_token_secret=$(az keyvault secret list --vault-name $ADB_TOKEN_KEYVAULT --query "[?ends_with(id, '/$databricks_token_secret_name')].id" -o tsv)
if [[ -z "$pat_token_secret" ]]; then
  echo 'generating PAT token'
  wsId=$(jq -r .id <<<"$databricks_metainfo")

  # Get a token for the global Databricks application.
  # The resource name is fixed and never changes.
  token_response=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d)
  token=$(jq .accessToken -r <<< "$token_response")

  # Get a token for the Azure management API
  token_response=$(az account get-access-token --resource https://management.core.windows.net/)
  azToken=$(jq .accessToken -r <<< "$token_response")

  api_response=$(curl -sf "$DATABRICKS_HOST/api/2.0/token/create" \
    -H "Authorization: Bearer $token" \
    -H "X-Databricks-Azure-SP-Management-Token:$azToken" \
    -H "X-Databricks-Azure-Workspace-Resource-Id:$wsId" \
    -d '{ "lifetime_seconds": 864000, "comment": "streaming-at-scale generated token" }')
  pat_token=$(jq .token_value -r <<< "$api_response")

  az keyvault secret set --vault-name "$ADB_TOKEN_KEYVAULT" --name "$databricks_token_secret_name" --value "$pat_token" -o tsv >>log.txt
fi

echo 'getting PAT token from Key Vault'
export DATABRICKS_TOKEN=$(az keyvault secret show --vault-name $ADB_TOKEN_KEYVAULT -n "$databricks_token_secret_name" --query value -o tsv)

fi
echo 'checking Databricks secrets scope exists'
declare SECRETS_SCOPE=$(databricks secrets list-scopes --output JSON | jq -e ".scopes[]? | select (.name == \"MAIN\") | .name") &>/dev/null
if [ -z "$SECRETS_SCOPE" ]; then
  echo 'creating Databricks secrets scope'
  databricks secrets create-scope --scope "MAIN" --initial-manage-principal "users"
fi

echo 'importing Databricks notebooks'
databricks workspace import_dir ../streaming/databricks/notebooks /Shared/streaming-at-scale --overwrite

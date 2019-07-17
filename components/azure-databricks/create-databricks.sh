#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting EH primary connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)
if [[ -n "${DATABRICKS_HOST:-}" && -n "${DATABRICKS_TOKEN:-}" ]]; then

  echo 'Not creating Databricks workspace. Using environment DATABRICKS_HOST and DATABRICKS_TOKEN settings'

else

if ! az resource show -g $RESOURCE_GROUP --resource-type Microsoft.Databricks/workspaces -n $ADB_WORKSPACE -o none 2>/dev/null; then
echo 'creating databricks workspace'
echo ". name: $ADB_WORKSPACE"
az group deployment create \
  --name $ADB_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --template-file ../components/azure-databricks/databricks-arm-template.json \
  --parameters \
  workspaceName=$ADB_WORKSPACE \
  tier=standard \
  -o tsv >>log.txt
fi

databricks_metainfo=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.Databricks/workspaces -n $ADB_WORKSPACE -o json)

echo 'creating Key Vault to store Databricks PAT token'
az keyvault create -g $RESOURCE_GROUP -n $ADB_TOKEN_KEYVAULT -o tsv >>log.txt

echo 'checking PAT token secret presence in Key Vault'
databricks_token_secret_name="DATABRICKS-TOKEN"
pat_token_secret=$(az keyvault secret list --vault-name $ADB_TOKEN_KEYVAULT --query "[?ends_with(id, '/$databricks_token_secret_name')].id" -o tsv)
if [[ -z "$pat_token_secret" ]]; then
  echo 'PAT token secret not present. Creating dummy entry for user to fill in manually'
  az keyvault secret set --vault-name $ADB_TOKEN_KEYVAULT -n "$databricks_token_secret_name" --file /dev/null -o tsv >>log.txt
fi

echo 'checking PAT token presence in Key Vault'
pat_token=$(az keyvault secret show --vault-name $ADB_TOKEN_KEYVAULT -n "$databricks_token_secret_name" --query value -o tsv)

if [[ -z "$pat_token" ]]; then
  echo 'PAT token not present. Requesting user to fill in manually'
  databricks_login_url=$(jq -r '"https://" + .location + ".azuredatabricks.net/aad/auth?has=&Workspace=" + .id + "&WorkspaceResourceGroupUri="+ .properties.managedResourceGroupId' <<<"$databricks_metainfo")

  kv_info=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.KeyVault/vaults -n $ADB_TOKEN_KEYVAULT -o json)
  kv_secrets_url=$(jq -r '"https://portal.azure.com/#@" + .properties.tenantId + "/resource" + .id + "/secrets"' <<<$kv_info)

  cat <<EOM
  ERROR: Missing PAT token in Key Vault (this is normal the first time you run this script).

  You need to manually create a Databricks PAT token and register it into the Key Vault as follows,
  then rerun this script or pipeline.

  - Navigate to:
      $databricks_login_url
    Create a PAT token and copy it to the clipboard:
      https://docs.azuredatabricks.net/api/latest/authentication.html#generate-a-token
  - Navigate to:
      $kv_secrets_url
    Click $databricks_token_secret_name
    Click "+ New Version"
    As value, enter the PAT token you copied
    Click Create
  - The script will wait for the PAT to be copied into the Key Vault
    If you stop the script, you can resume it running the following command:
      ./create-solution.sh -d "$PREFIX" -t $TESTTYPE -s PT

EOM
  
  echo 'waiting for PAT (polling every 5 secs)...'
  while : ; do
    pat_token=$(az keyvault secret show --vault-name "$ADB_TOKEN_KEYVAULT" --name "$databricks_token_secret_name" --query value -o tsv | grep dapi || true)	
    if [ ! -z "$pat_token" ]; then break; fi
	  sleep 5
  done
  echo 'PAT detected'
fi

# Databricks CLI automatically picks up configuration from these two environment variables.
export DATABRICKS_HOST=$(jq -r '"https://" + .location + ".azuredatabricks.net"' <<<"$databricks_metainfo")
export DATABRICKS_TOKEN="$pat_token"

fi
echo 'checking Databricks secrets scope exists'
declare SECRETS_SCOPE=$(databricks secrets list-scopes --output JSON | jq -e ".scopes[]? | select (.name == \"MAIN\") | .name") &>/dev/null
if [ -z "$SECRETS_SCOPE" ]; then
  echo 'creating Databricks secrets scope'
  databricks secrets create-scope --scope "MAIN" --initial-manage-principal "users"
fi

echo 'importing Databricks notebooks'
databricks workspace import_dir ../streaming/databricks/notebooks /Shared/streaming-at-scale --overwrite


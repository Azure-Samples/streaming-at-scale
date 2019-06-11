#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting EH primary connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)

echo "getting cosmosdb master key"
COSMOSDB_MASTER_KEY=$(az cosmosdb list-keys -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryMasterKey" -o tsv)

echo 'creating databricks workspace'
echo ". name: $ADB_WORKSPACE"
az group deployment create \
  --name $ADB_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --template-file arm/databricks.arm.json \
  --parameters \
  workspaceName=$ADB_WORKSPACE \
  location=$LOCATION \
  tier=standard \
  -o tsv >>log.txt

databricks_metainfo=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.Databricks/workspaces -n $ADB_WORKSPACE)

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

  kv_info=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.KeyVault/vaults -n $ADB_TOKEN_KEYVAULT)
  kv_secrets_url=$(jq -r '"https://portal.azure.com/#@" + .properties.tenantId + "/resource" + .id + "/secrets"' <<<$kv_info)

  cat <<EOM
  ERROR: Missing PAT token in Key Vault (this is normal the first time you run this script).

  You need to manually create a Databricks PAT token and register it into the Key Vault as follows,
    then rerun this script or pipeline.

  - Navigate to $databricks_login_url
    create a PAT token and copy it to the clipboard.
  - Navigate to $kv_secrets_url
    click $databricks_token_secret_name
    click + New version
    As value, enter the PAT token you copied
    click Create
EOM
  exit 1
fi

# Databricks CLI automatically picks up configuration from these two environment variables.
export DATABRICKS_HOST=$(jq -r '"https://" + .location + ".azuredatabricks.net"' <<<"$databricks_metainfo")
export DATABRICKS_TOKEN="$pat_token"

echo 'checking Databricks secrets scope exists'
if ! databricks secrets list-scopes --output JSON | jq -e ".scopes[] | select (.name == \"MAIN\")" >/dev/null; then
  echo 'creating Databricks secrets scope'
  databricks secrets create-scope --scope "MAIN" --initial-manage-principal "users"
fi

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "cosmosdb-write-master-key" --string-value "$COSMOSDB_MASTER_KEY"
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"

cluster_def=$(
  cat <<JSON
{
  "spark_version": "5.4.x-scala2.11",
  "node_type_id": "Standard_DS3_v2",
  "autoscale": {
    "min_workers": 1,
    "max_workers": 3
  },
  "spark_env_vars": {
    "PYSPARK_PYTHON": "/databricks/python3/bin/python3"
  }
}
JSON
)

echo 'Importing Spark library'

#Cosmos DB must be imported as Uber JAR and not resolved through maven coordinates,
# see https://kb.databricks.com/data-sources/cosmosdb-connector-lib-conf.html
cosmosdb_spark_jar=azure-cosmosdb-spark_2.4.0_2.11-1.4.0-uber.jar
curl -O "http://central.maven.org/maven2/com/microsoft/azure/azure-cosmosdb-spark_2.4.0_2.11/1.4.0/$cosmosdb_spark_jar"
databricks fs cp --overwrite "$cosmosdb_spark_jar" "dbfs:/mnt/streaming-at-scale/$cosmosdb_spark_jar"

echo 'Importing Databricks notebooks'

databricks workspace import_dir databricks/notebooks /Shared/streaming-at-scale --overwrite

echo 'Running Databricks notebooks' | tee -a log.txt

# It is recommended to run each streaming job on a dedicated cluster.
for notebook in databricks/notebooks/*.scala; do

  notebook_name=$(basename $notebook .scala)
  notebook_path=/Shared/streaming-at-scale/$notebook_name

  echo "starting Databricks notebook job for $notebook"
  job=$(databricks jobs create --json "$(
    cat <<JSON
  {
    "name": "Sample $notebook_name",
    "new_cluster": $cluster_def,
    "libraries": [
        {
          "maven": {
            "coordinates": "com.microsoft.azure:azure-eventhubs-spark_2.11:2.3.12"
          }
        },
        {
          "jar": "dbfs:/mnt/streaming-at-scale/azure-cosmosdb-spark_2.4.0_2.11-1.4.0-uber.jar"
        }
    ],
    "timeout_seconds": 1200,
    "notebook_task": {
      "notebook_path": "$notebook_path",
      "base_parameters": {
        "cosmosdb-endpoint": "https://$COSMOSDB_SERVER_NAME.documents.azure.com:443",
        "cosmosdb-database": "$COSMOSDB_DATABASE_NAME",
        "cosmosdb-collection": "$COSMOSDB_COLLECTION_NAME",
        "eventhub-consumergroup": "$EVENTHUB_CG"
      }
    }
  }
JSON
  )")
  job_id=$(echo $job | jq .job_id)

  run=$(databricks jobs run-now --job-id $job_id)

  # Echo job web page URL to task output to facilitate debugging
  run_id=$(echo $run | jq .run_id)
  databricks runs get --run-id "$run_id" | jq -r .run_page_url >>log.txt

done # for each notebook

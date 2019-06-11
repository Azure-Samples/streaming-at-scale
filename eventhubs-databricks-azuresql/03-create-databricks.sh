#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting EH primary connection string'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv)

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

echo 'creating Key Vault to store Databricks Personal Access Token (PAT)'
az keyvault create -g $RESOURCE_GROUP -n $ADB_TOKEN_KEYVAULT -o tsv >>log.txt

databricks_login_url=$(jq -r '"https://" + .location + ".azuredatabricks.net/aad/auth?has=&Workspace=" + .id + "&WorkspaceResourceGroupUri="+ .properties.managedResourceGroupId' <<<"$databricks_metainfo")
echo 'Please manually create a Databricks PAT token and enter it here to be kept in Key Vault. '
echo -n 'Navigate to $databricks_login_url, click the person icon in the top right corner, click User Settings, and create a PAT token. Paste your PAT token here and press Enter to continue: '
read pat_token

databricks_token_secret_name="DATABRICKS-TOKEN"
az keyvault secret set --vault-name $ADB_TOKEN_KEYVAULT -n "$databricks_token_secret_name" --value "$pat_token"

# Databricks CLI automatically picks up configuration from these two environment variables.
export DATABRICKS_HOST=$(jq -r '"https://" + .location + ".azuredatabricks.net"' <<<"$databricks_metainfo")
export DATABRICKS_TOKEN="$pat_token"

echo 'checking Databricks secrets scope exists'
if ! databricks secrets list-scopes --output JSON | jq -e ".scopes[] | select (.name == \"MAIN\")" >/dev/null; then
    echo 'creating Databricks secrets scope'
    databricks secrets create-scope --scope "MAIN" --initial-manage-principal "users"
fi

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "azuresql-pass" --string-value "$SQL_ADMIN_PASS"
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"

# TODO: MAKE CLUSTER DEFINITION CONFIGURABLE PER 1K, 5K, 10K MESSAGES
cluster_def=$(
    cat <<JSON
{
    "spark_version": "5.4.x-scala2.11",
    "node_type_id": "Standard_DS3_v2",
    "num_workers": $EVENTHUB_PARTITIONS,
    "spark_env_vars": {
        "PYSPARK_PYTHON": "/databricks/python3/bin/python3"
    }
}
JSON
)

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
            }
        ],
        "notebook_task": {
            "notebook_path": "$notebook_path",
            "base_parameters": {
                "eventhub-consumergroup": "$EVENTHUB_CG",
                "azuresql-servername": "$SQL_SERVER_NAME"
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
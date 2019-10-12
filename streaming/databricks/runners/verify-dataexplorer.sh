#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo "getting Data Explorer URL"
kustoURL=$(az kusto cluster show -g $RESOURCE_GROUP -n $DATAEXPLORER_CLUSTER --query uri -o tsv)

echo "getting Storage key"
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

echo "getting Service Principal ID and password"
appId=$(az keyvault secret show --vault-name $DATAEXPLORER_KEYVAULT -n $DATAEXPLORER_CLIENT_NAME-id --query value -o tsv)
password=$(az keyvault secret show --vault-name $DATAEXPLORER_KEYVAULT -n $DATAEXPLORER_CLIENT_NAME-password --query value -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "dataexplorer-client-password" --string-value "$password"
databricks secrets put --scope "MAIN" --key "dataexplorer-storage-key" --string-value "$AZURE_STORAGE_KEY"

source ../streaming/databricks/job/run-databricks-job.sh verify-dataexplorer true "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "com.microsoft.azure.kusto:spark-kusto-connector:1.0.0-BETA-06", "exclusions": ["javax.mail:mail"] } } ]
  | .notebook_task.base_parameters."test-output-path" = "$DATABRICKS_TESTOUTPUTPATH"
  | .notebook_task.base_parameters."dataexplorer-cluster" = "$kustoURL"
  | .notebook_task.base_parameters."dataexplorer-database" = "$DATAEXPLORER_DATABASE"
  | .notebook_task.base_parameters."dataexplorer-query" = "EventTable"
  | .notebook_task.base_parameters."dataexplorer-client-id" = "$appId"
  | .notebook_task.base_parameters."dataexplorer-storage-account" = "$AZURE_STORAGE_ACCOUNT"
  | .notebook_task.base_parameters."dataexplorer-storage-container" = "dataexplorer"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
JQ
)"

source ../streaming/databricks/runners/verify-download-result.sh

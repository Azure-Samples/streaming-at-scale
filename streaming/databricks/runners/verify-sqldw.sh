#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo "retrieving storage account key"
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

echo "creating Polybase container"
az storage container create --account-name $AZURE_STORAGE_ACCOUNT -n sqldw -o tsv >> log.txt

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "sqldw-pass" --string-value "$SQL_ADMIN_PASS"
databricks secrets put --scope "MAIN" --key "storage-account-key" --string-value "$AZURE_STORAGE_KEY"

source ../streaming/databricks/job/run-databricks-job.sh verify-sqldw true "$(cat <<JQ
  .notebook_task.base_parameters."sqldw-servername" = "$SQL_SERVER_NAME"
  | .notebook_task.base_parameters."sqldw-user" = "serveradmin"
  | .notebook_task.base_parameters."sqldw-tempstorage-account" = "$AZURE_STORAGE_ACCOUNT"
  | .notebook_task.base_parameters."sqldw-tempstorage-container" = "sqldw"
  | .notebook_task.base_parameters."sqldw-table" = "$SQL_TABLE_NAME"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
  | .notebook_task.base_parameters."assert-duplicate-fraction" = "$ALLOW_DUPLICATE_FRACTION"
JQ
)"

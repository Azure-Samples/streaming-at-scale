#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

# TSI writes data into a storage container named after the environment ID.
# Navigate the TSI API to retrieve the environment ID for the given TSI resource.

tsi_id=$(az resource show -g $RESOURCE_GROUP -n $TSI_ENVIRONMENT \
  --resource-type Microsoft.TimeSeriesInsights/environments \
  --query properties.dataAccessId -o tsv)

tsi_data="wasbs://env-$tsi_id@$AZURE_STORAGE_ACCOUNT.blob.core.windows.net/V=1/PT=Time"

echo "retrieving storage account key"
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

databricks secrets put --scope "MAIN" --key "storage-account-key" --string-value "$AZURE_STORAGE_KEY"

source ../streaming/databricks/job/run-databricks-job.sh verify-timeseriesinsights-parquet true "$(cat <<JQ
  .new_cluster.spark_conf."spark.hadoop.fs.azure.account.key.$AZURE_STORAGE_ACCOUNT.blob.core.windows.net" = "$AZURE_STORAGE_KEY"
  | .notebook_task.base_parameters."storage-path" = "$tsi_data"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
JQ
)"

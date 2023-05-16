#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

# $STORAGE_EVENT_QUEUE may be blank, in this case, directory listing is used

echo "getting Data Lake Storage Gen2 key"
STORAGE_GEN2_KEY=$(az storage account keys list -n $AZURE_STORAGE_ACCOUNT_GEN2 -g $RESOURCE_GROUP --query '[?keyName==`key1`].value' -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "storage-account-key" --string-value "$STORAGE_GEN2_KEY"

delta_table="events_$PREFIX"
checkpoints_dir=dbfs:/streaming_at_scale/checkpoints/blob-json-to-delta/"$delta_table"
echo "Deleting checkpoints directory $checkpoints_dir"
databricks fs rm -r "$checkpoints_dir"

source ../streaming/databricks/job/run-databricks-job.sh blob-json-to-delta false "$(cat <<JQ
  .notebook_task.base_parameters."storage-account" = "$AZURE_STORAGE_ACCOUNT_GEN2"
  | .notebook_task.base_parameters."notification-queue" = "$STORAGE_EVENT_QUEUE"
  | .notebook_task.base_parameters."delta-table" = "$delta_table"
JQ
)"

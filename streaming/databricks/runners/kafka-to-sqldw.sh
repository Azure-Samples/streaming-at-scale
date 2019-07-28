#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "retrieving storage account key"
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "sqldw-pass" --string-value "$SQL_ADMIN_PASS"
databricks secrets put --scope "MAIN" --key "sqldw-tempstorage-key" --string-value "$AZURE_STORAGE_KEY"

checkpoints_dir=dbfs:/streaming_at_scale/checkpoints/streaming-sqldw
echo "Deleting checkpoints directory $checkpoints_dir"
databricks fs rm -r "$checkpoints_dir"

source ../streaming/databricks/job/run-databricks-job.sh kafka-to-sqldw false "$(cat <<JQ
  .notebook_task.base_parameters."kafka-servers" = "$KAFKA_BROKERS"
  | .notebook_task.base_parameters."kafka-topics" = "$KAFKA_TOPIC"
  | .notebook_task.base_parameters."sqldw-servername" = "$SQL_SERVER_NAME"
  | .notebook_task.base_parameters."sqldw-user" = "serveradmin"
  | .notebook_task.base_parameters."sqldw-tempstorage-account" = "$AZURE_STORAGE_ACCOUNT"
  | .notebook_task.base_parameters."sqldw-tempstorage-container" = "sqldw"
  | .notebook_task.base_parameters."sqldw-table" = "$SQL_TABLE_NAME"
JQ
)"

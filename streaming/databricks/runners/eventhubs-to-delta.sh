#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "getting Data Lake Storage Gen2 key"
STORAGE_GEN2_KEY=$(az storage account keys list -n $AZURE_STORAGE_ACCOUNT_GEN2 -g $RESOURCE_GROUP --query '[?keyName==`key1`].value' -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"
databricks secrets put --scope "MAIN" --key "storage-account-key" --string-value "$STORAGE_GEN2_KEY"

../streaming/databricks/job/run-databricks-job.sh eventhubs-to-delta "$(cat <<JQ
  .notebook_task.base_parameters."eventhub-consumergroup" = "$EVENTHUB_CG"
  | .notebook_task.base_parameters."eventhub-maxEventsPerTrigger" = "$DATABRICKS_MAXEVENTSPERTRIGGER"
  | .notebook_task.base_parameters."storage-account" = "$AZURE_STORAGE_ACCOUNT_GEN2"
JQ
)"

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting shared access key'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Listen --query "primaryConnectionString" -o tsv)

echo "getting Data Lake Storage Gen2 key"
STORAGE_GEN2_KEY=$(az storage account keys list -n $AZURE_STORAGE_ACCOUNT_GEN2 -g $RESOURCE_GROUP --query '[?keyName==`key1`].value' -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"
databricks secrets put --scope "MAIN" --key "storage-account-key" --string-value "$STORAGE_GEN2_KEY"

checkpoints_dir=dbfs:/streaming_at_scale/checkpoints/streaming-delta
echo "Deleting checkpoints directory $checkpoints_dir"
databricks fs rm -r "$checkpoints_dir"

source ../streaming/databricks/job/run-databricks-job.sh eventhubs-to-delta false "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "com.microsoft.azure:azure-eventhubs-spark_2.11:2.3.13" } } ]
  | .notebook_task.base_parameters."eventhub-consumergroup" = "$EVENTHUB_CG"
  | .notebook_task.base_parameters."eventhub-maxEventsPerTrigger" = "$DATABRICKS_MAXEVENTSPERTRIGGER"
  | .notebook_task.base_parameters."storage-account" = "$AZURE_STORAGE_ACCOUNT_GEN2"
  | .notebook_task.base_parameters."delta-table" = "events_$PREFIX"
JQ
)"

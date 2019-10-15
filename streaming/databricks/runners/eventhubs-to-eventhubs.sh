#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting shared access keys'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Listen --query "primaryConnectionString" -o tsv)
EVENTHUB_CS_OUT=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Send --query "primaryConnectionString" -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"
databricks secrets put --scope "MAIN" --key "event-hubs-write-connection-string" --string-value "$EVENTHUB_CS_OUT;EntityPath=$EVENTHUB_NAME"

checkpoints_dir=dbfs:/streaming_at_scale/checkpoints/eventhubs-to-eventhubs
echo "Deleting checkpoints directory $checkpoints_dir"
databricks fs rm -r "$checkpoints_dir"

source ../streaming/databricks/job/run-databricks-job.sh eventhubs-to-eventhubs false "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "com.microsoft.azure:azure-eventhubs-spark_2.11:2.3.13" } } ]
  | .notebook_task.base_parameters."eventhub-consumergroup" = "$EVENTHUB_CG"
  | .notebook_task.base_parameters."eventhub-maxEventsPerTrigger" = "$DATABRICKS_MAXEVENTSPERTRIGGER"
JQ
)"

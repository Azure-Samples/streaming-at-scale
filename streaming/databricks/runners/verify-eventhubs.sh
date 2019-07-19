#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo 'getting shared access key'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Listen --query "primaryConnectionString" -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"

source ../streaming/databricks/job/run-databricks-job.sh verify-eventhubs true "$(cat <<JQ
  .notebook_task.base_parameters."eventhub-consumergroup" = "$EVENTHUB_CG"
JQ
)"

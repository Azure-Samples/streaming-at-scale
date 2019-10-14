#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo 'getting shared access key'
EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Listen --query "primaryConnectionString" -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"

source ../streaming/databricks/job/run-databricks-job.sh verify-eventhubs true "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "com.microsoft.azure:azure-eventhubs-spark_2.11:2.3.13" } } ]
  | .notebook_task.base_parameters."test-output-path" = "$DATABRICKS_TESTOUTPUTPATH"
  | .notebook_task.base_parameters."eventhub-consumergroup" = "$EVENTHUB_CG"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
  | .notebook_task.base_parameters."assert-duplicate-fraction" = "$ALLOW_DUPLICATE_FRACTION"
  | .notebook_task.base_parameters."assert-outofsequence-fraction" = "$ALLOW_OUTOFSEQUENCE_FRACTION"
JQ
)"

source ../streaming/databricks/runners/verify-download-result.sh

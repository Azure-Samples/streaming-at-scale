#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo "getting cosmosdb read-only master key"
COSMOSDB_MASTER_KEY=$(az cosmosdb keys list -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryReadonlyMasterKey" -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "cosmosdb-write-master-key" --string-value "$COSMOSDB_MASTER_KEY"

cosmosdb_spark_jar_version=1.5.0
cosmosdb_spark_jar=azure-cosmosdb-spark_2.4.0_2.11-$cosmosdb_spark_jar_version-uber.jar

source ../streaming/databricks/job/run-databricks-job.sh verify-cosmosdb true "$(cat <<JQ
  .libraries += [{"jar": "dbfs:/mnt/streaming-at-scale/$cosmosdb_spark_jar"}]
  | .notebook_task.base_parameters."test-output-path" = "$DATABRICKS_TESTOUTPUTPATH"
  | .notebook_task.base_parameters."cosmosdb-endpoint" = "https://$COSMOSDB_SERVER_NAME.documents.azure.com:443"
  | .notebook_task.base_parameters."cosmosdb-database" = "$COSMOSDB_DATABASE_NAME"
  | .notebook_task.base_parameters."cosmosdb-collection" = "$COSMOSDB_COLLECTION_NAME"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
  | .notebook_task.base_parameters."assert-duplicate-fraction" = "$ALLOW_DUPLICATE_FRACTION"
  | .notebook_task.base_parameters."assert-outofsequence-fraction" = "$ALLOW_OUTOFSEQUENCE_FRACTION"
JQ
)"

source ../streaming/databricks/runners/verify-download-result.sh

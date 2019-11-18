#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting shared access key'
source ../components/azure-event-hubs/get-eventhubs-connection-string.sh "$EVENTHUB_NAMESPACE" "Listen"

echo "getting cosmosdb master key"
COSMOSDB_MASTER_KEY=$(az cosmosdb keys list -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryMasterKey" -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "event-hubs-read-connection-string" --string-value "$EVENTHUB_CS;EntityPath=$EVENTHUB_NAME"
databricks secrets put --scope "MAIN" --key "cosmosdb-write-master-key" --string-value "$COSMOSDB_MASTER_KEY"

checkpoints_dir=dbfs:/streaming_at_scale/checkpoints/eventhubs-to-cosmosdb
echo "Deleting checkpoints directory $checkpoints_dir"
databricks fs rm -r "$checkpoints_dir"

echo 'importing Spark library'
# Cosmos DB must be imported as Uber JAR and not resolved through maven coordinates,
# see https://kb.databricks.com/data-sources/cosmosdb-connector-lib-conf.html
cosmosdb_spark_jar=azure-cosmosdb-spark_2.4.0_2.11-1.4.1-uber.jar
jar_tempfile=$(mktemp)
curl -fsL -o "$jar_tempfile" "http://central.maven.org/maven2/com/microsoft/azure/azure-cosmosdb-spark_2.4.0_2.11/1.4.1/$cosmosdb_spark_jar"
databricks fs cp --overwrite "$jar_tempfile" "dbfs:/mnt/streaming-at-scale/$cosmosdb_spark_jar"
rm $jar_tempfile

source ../streaming/databricks/job/run-databricks-job.sh eventhubs-to-cosmosdb false "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "com.microsoft.azure:azure-eventhubs-spark_2.11:2.3.13" } } ]
  | .libraries += [{"jar": "dbfs:/mnt/streaming-at-scale/azure-cosmosdb-spark_2.4.0_2.11-1.4.1-uber.jar"}]
  | .notebook_task.base_parameters."eventhub-consumergroup" = "$EVENTHUB_CG"
  | .notebook_task.base_parameters."eventhub-maxEventsPerTrigger" = "$DATABRICKS_MAXEVENTSPERTRIGGER"
  | .notebook_task.base_parameters."cosmosdb-endpoint" = "https://$COSMOSDB_SERVER_NAME.documents.azure.com:443"
  | .notebook_task.base_parameters."cosmosdb-database" = "$COSMOSDB_DATABASE_NAME"
  | .notebook_task.base_parameters."cosmosdb-collection" = "$COSMOSDB_COLLECTION_NAME"
JQ
)"

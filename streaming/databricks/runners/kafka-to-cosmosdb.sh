#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "retrieving storage account key"
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

echo "getting cosmosdb master key"
COSMOSDB_MASTER_KEY=$(az cosmosdb keys list -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryMasterKey" -o tsv)

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "kafka-sasl-jaas-config" --string-value "$KAFKA_SASL_JAAS_CONFIG"
databricks secrets put --scope "MAIN" --key "cosmosdb-write-master-key" --string-value "$COSMOSDB_MASTER_KEY"

checkpoints_dir=dbfs:/streaming_at_scale/checkpoints/streaming-cosmosdb
echo "Deleting checkpoints directory $checkpoints_dir"
databricks fs rm -r "$checkpoints_dir"

echo 'importing Spark library'
# Cosmos DB must be imported as Uber JAR and not resolved through maven coordinates,
# see https://kb.databricks.com/data-sources/cosmosdb-connector-lib-conf.html
cosmosdb_spark_jar=azure-cosmosdb-spark_2.4.0_2.11-1.4.0-uber.jar
jar_tempfile=$(mktemp)
curl -fsL -o "$jar_tempfile" "http://central.maven.org/maven2/com/microsoft/azure/azure-cosmosdb-spark_2.4.0_2.11/1.4.0/$cosmosdb_spark_jar"
databricks fs cp --overwrite "$jar_tempfile" "dbfs:/mnt/streaming-at-scale/$cosmosdb_spark_jar"
rm $jar_tempfile

source ../streaming/databricks/job/run-databricks-job.sh kafka-to-cosmosdb false "$(cat <<JQ
  .libraries += [{"jar": "dbfs:/mnt/streaming-at-scale/azure-cosmosdb-spark_2.4.0_2.11-1.4.0-uber.jar"}]
  | .libraries += [ { "maven": { "coordinates": "org.apache.kafka:kafka-clients:2.0.0" } } ]
  | .notebook_task.base_parameters."kafka-servers" = "$KAFKA_BROKERS"
  | .notebook_task.base_parameters."kafka-sasl-mechanism" = "$KAFKA_SASL_MECHANISM"
  | .notebook_task.base_parameters."kafka-security-protocol" = "$KAFKA_SECURITY_PROTOCOL"
  | .notebook_task.base_parameters."kafka-topics" = "$KAFKA_TOPIC"
  | .notebook_task.base_parameters."cosmosdb-endpoint" = "https://$COSMOSDB_SERVER_NAME.documents.azure.com:443"
  | .notebook_task.base_parameters."cosmosdb-database" = "$COSMOSDB_DATABASE_NAME"
  | .notebook_task.base_parameters."cosmosdb-collection" = "$COSMOSDB_COLLECTION_NAME"
JQ
)"

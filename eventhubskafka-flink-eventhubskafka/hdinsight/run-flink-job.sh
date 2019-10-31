#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

container=flinkscriptaction

echo 'Getting SAS for script action script'

script_uri=$(az storage blob generate-sas --account-name $AZURE_STORAGE_ACCOUNT -c $container \
   --policy-name HDInsightRead --full-uri -n run-flink-job.sh -o tsv
)

echo 'uploading Flink job jar'

jarname="apps/flink/jobs/$(uuidgen).jar"
az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT -c $HDINSIGHT_NAME \
    -n $jarname -f flink-kafka-consumer/target/assembly/flink-kafka-consumer-simple-relay.jar \
    -o tsv >> log.txt

echo 'getting EH connection strings'
EVENTHUB_CS_IN_LISTEN=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Listen --query "primaryConnectionString" -o tsv)
EVENTHUB_CS_OUT_SEND=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE_OUT --name Send --query "primaryConnectionString" -o tsv)
KAFKA_CS_IN_LISTEN="org.apache.kafka.common.security.plain.PlainLoginModule required username=\\\"\\\$ConnectionString\\\" password=\\\"$EVENTHUB_CS_IN_LISTEN\\\";"
KAFKA_CS_OUT_SEND="org.apache.kafka.common.security.plain.PlainLoginModule required username=\\\"\\\$ConnectionString\\\" password=\\\"$EVENTHUB_CS_OUT_SEND\\\";"

echo 'running script action'

az hdinsight script-action execute -g $RESOURCE_GROUP --cluster-name $HDINSIGHT_NAME \
  --name RunFlinkJob \
  --script-uri "$script_uri" \
  --script-parameters "\"wasbs:///$jarname\" --kafka.in.topic \"$EVENTHUB_NAME\" --kafka.in.bootstrap.servers \"$EVENTHUB_NAMESPACE.servicebus.windows.net:9093\" --kafka.in.request.timeout.ms \"15000\" --kafka.in.sasl.mechanism PLAIN --kafka.in.security.protocol SASL_SSL --kafka.in.sasl.jaas.config \"$KAFKA_CS_IN_LISTEN\" --kafka.out.topic \"$EVENTHUB_NAME\" --kafka.out.bootstrap.servers \"$EVENTHUB_NAMESPACE.servicebus.windows.net:9093\" --kafka.out.request.timeout.ms \"15000\" --kafka.out.sasl.mechanism PLAIN --kafka.out.security.protocol SASL_SSL --kafka.out.sasl.jaas.config \"$KAFKA_CS_OUT_SEND\"" \
  --roles workernode \
  -o tsv >> log.txt

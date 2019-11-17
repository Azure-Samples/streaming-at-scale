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
az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT -c $HDINSIGHT_YARN_NAME \
    -n $jarname -f flink-kafka-consumer/target/assembly/flink-kafka-consumer-$FLINK_JOBTYPE.jar \
    -o tsv >> log.txt

echo 'running script action'

script_param=$(printf "\"wasbs:///%q\" --parallelism "$FLINK_PARALLELISM" --kafka.in.topic %q --kafka.in.bootstrap.servers %q --kafka.in.request.timeout.ms %q --kafka.in.sasl.mechanism %q --kafka.in.security.protocol %q --kafka.in.sasl.jaas.config %q --kafka.out.topic %q --kafka.out.bootstrap.servers %q --kafka.out.request.timeout.ms %q --kafka.out.sasl.mechanism %q --kafka.out.security.protocol %q --kafka.out.sasl.jaas.config %q" "$jarname" "$KAFKA_TOPIC" "$KAFKA_IN_LISTEN_BROKERS" "60000" "$KAFKA_IN_LISTEN_SASL_MECHANISM" "$KAFKA_IN_LISTEN_SECURITY_PROTOCOL" "$KAFKA_IN_LISTEN_JAAS_CONFIG" "$KAFKA_OUT_TOPIC" "$KAFKA_OUT_SEND_BROKERS" "60000" "$KAFKA_OUT_SEND_SASL_MECHANISM" "$KAFKA_OUT_SEND_SECURITY_PROTOCOL" "$KAFKA_OUT_SEND_JAAS_CONFIG")
 
az hdinsight script-action execute -g $RESOURCE_GROUP --cluster-name $HDINSIGHT_YARN_NAME \
  --name RunFlinkJob \
  --script-uri "$script_uri" \
  --script-parameters "$script_param" \
  --roles workernode \
  -o tsv >> log.txt

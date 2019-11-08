#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'building Flink job'
mvn clean install -f flink-application-insights
mvn clean package -f flink-kafka-consumer -P package-$FLINK_JOBTYPE

echo 'retrieving Flink version from build'
eval "FLINK_VERSION$(grep '^flink.version=.*' flink-kafka-consumer/target/maven.properties | grep -o '=.*' )"
eval "FLINK_SCALA_VERSION$(grep '^scala.binary.version=.*' flink-kafka-consumer/target/maven.properties | grep -o '=.*' )"

echo ". Flink version: $FLINK_VERSION"
echo ". Flink Scala version: $FLINK_SCALA_VERSION"

if [ "$INGESTION_PLATFORM" == "hdinsightkafka" ]; then
  source ../components/azure-hdinsight/get-hdinsight-kafka-brokers.sh
fi

if [ "$INGESTION_PLATFORM" == "eventhubskafka" ]; then
  source ../components/azure-event-hubs/get-eventhubs-kafka-brokers.sh "$EVENTHUB_NAMESPACE" "Listen"
fi

  KAFKA_IN_LISTEN_BROKERS=$KAFKA_BROKERS
  KAFKA_IN_LISTEN_SASL_MECHANISM=$KAFKA_SASL_MECHANISM
  KAFKA_IN_LISTEN_SECURITY_PROTOCOL=$KAFKA_SECURITY_PROTOCOL
  KAFKA_IN_LISTEN_JAAS_CONFIG=$KAFKA_SASL_JAAS_CONFIG

if [ "$INGESTION_PLATFORM" == "eventhubskafka" ]; then
  source ../components/azure-event-hubs/get-eventhubs-kafka-brokers.sh "$EVENTHUB_NAMESPACE_OUT" "Send"
fi

  KAFKA_OUT_SEND_BROKERS=$KAFKA_BROKERS
  KAFKA_OUT_SEND_SASL_MECHANISM=$KAFKA_SASL_MECHANISM
  KAFKA_OUT_SEND_SECURITY_PROTOCOL=$KAFKA_SECURITY_PROTOCOL
  KAFKA_OUT_SEND_JAAS_CONFIG=$KAFKA_SASL_JAAS_CONFIG


if [ "$FLINK_PLATFORM" == "hdinsight" ]; then
  source hdinsight/provision-hdinsight-flink-cluster.sh
  source hdinsight/run-flink-job.sh
else
  # Create service principal for AKS.
  # Run as early as possible in script, as principal takes time to become available for RBAC operations.
  source ../components/azure-common/create-service-principal.sh

  source ../components/azure-monitor/create-log-analytics.sh
  source monitoring/provision-applicationinsights.sh
  pushd kubernetes > /dev/null
    source provision-aks-flink-cluster.sh
  popd
fi

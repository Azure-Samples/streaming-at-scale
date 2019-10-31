#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'building Flink job'
mvn clean package -f flink-kafka-consumer -P package-$FLINK_JOBTYPE

echo 'retrieving Flink version from build'
eval "FLINK_VERSION$(grep '^flink.version=.*' flink-kafka-consumer/target/maven.properties | grep -o '=.*' )"
eval "FLINK_SCALA_VERSION$(grep '^scala.binary.version=.*' flink-kafka-consumer/target/maven.properties | grep -o '=.*' )"

echo ". Flink version: $FLINK_VERSION"
echo ". Flink Scala version: $FLINK_SCALA_VERSION"

if [ "$FLINK_PLATFORM" == "hdinsight" ]; then
  source hdinsight/provision-hdinsight-flink-cluster.sh
  source hdinsight/run-flink-job.sh
else
  pushd kubernetes > /dev/null
    source provision-aks-flink-cluster.sh
  popd
fi

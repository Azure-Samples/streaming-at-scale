#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'building flink job'
mvn clean package -f flink-kafka-consumer -P package-$FLINK_JOBTYPE

if [ "$FLINK_PLATFORM" == "hdinsight" ]; then
  source hdinsight/provision-hdinsight-flink-cluster.sh
else
  pushd kubernetes > /dev/null
    source provision-aks-flink-cluster.sh
  popd
fi

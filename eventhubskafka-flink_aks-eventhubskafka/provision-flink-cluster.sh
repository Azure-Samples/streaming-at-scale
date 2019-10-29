#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'building flink job'
mvn -f flink-kafka-consumer clean package

if [ "$FLINK_PLATFORM" == "hdinsight" ]; then
  pushd hdinsight > /dev/null
    source provision-hdinsight-flink-cluster.sh
  popd
else
  pushd kubernetes > /dev/null
    source provision-aks-flink-cluster.sh
  popd
fi

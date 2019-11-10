#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'building Flink job'

pushd ../components/apache-flink/ > /dev/null
  mvn install -f flink-application-insights
  mvn verify -f flink-kafka-consumer -P package-$FLINK_JOBTYPE

  export FLINK_VERSION=$(grep '^flink.version=.*' flink-kafka-consumer/target/maven.properties | sed 's/.*=//')

  echo ". Flink version: $FLINK_VERSION"
popd > /dev/null

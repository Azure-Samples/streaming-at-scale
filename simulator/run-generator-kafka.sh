#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

OUTPUT_FORMAT="kafka"
kafka_properties=$(cat <<OPTIONS
{
  "bootstrap.servers": "$KAFKA_BROKERS",
  "sasl.mechanism": "$KAFKA_SASL_MECHANISM",
  "security.protocol": "$KAFKA_SECURITY_PROTOCOL",
  "sasl.username": "$KAFKA_SASL_USERNAME",
  "sasl.password": "$KAFKA_SASL_PASSWORD"
}
OPTIONS
)


SIMULATOR_VARIABLES="KafkaTopic=$KAFKA_TOPIC"
SIMULATOR_CONNECTION_SETTING="KafkaConnectionProperties=$kafka_properties"

source ../simulator/run-simulator.sh

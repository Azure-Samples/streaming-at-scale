#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

OUTPUT_FORMAT="kafka"
OUTPUT_OPTIONS=$(cat <<OPTIONS
{
  "kafka.bootstrap.servers": "$KAFKA_BROKERS",
  "kafka.sasl.mechanism": "$KAFKA_SASL_MECHANISM",
  "kafka.security.protocol": "$KAFKA_SECURITY_PROTOCOL",
  "topic": "$KAFKA_TOPIC"
}
OPTIONS
)

SECURE_OUTPUT_OPTIONS=$(echo "$KAFKA_SASL_JAAS_CONFIG" | jq --raw-input '{"kafka.sasl.jaas.config":.}')

source ../simulator/create-generator-instances.sh

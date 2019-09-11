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
SECURE_OUTPUT_OPTIONS=$(cat <<OPTIONS
{
  "kafka.sasl.jaas.config": "${KAFKA_SASL_JAAS_CONFIG//\"/\"}"
}
OPTIONS
)

source ../simulator/create-generator-instances.sh

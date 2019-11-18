#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../components/azure-hdinsight/get-hdinsight-kafka-brokers.sh

KAFKA_OUT_SEND_BROKERS=$KAFKA_BROKERS
KAFKA_OUT_SEND_SASL_MECHANISM=$KAFKA_SASL_MECHANISM
KAFKA_OUT_SEND_SECURITY_PROTOCOL=$KAFKA_SECURITY_PROTOCOL
KAFKA_OUT_SEND_JAAS_CONFIG=$KAFKA_SASL_JAAS_CONFIG


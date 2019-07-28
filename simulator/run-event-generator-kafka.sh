#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

OUTPUT_FORMAT="kafka"
OUTPUT_OPTIONS="{\"kafka.bootstrap.servers\": \"$KAFKA_BROKERS\", \"topic\": \"streaming\"}"
SECURE_OUTPUT_OPTIONS="{}"
VNET_OPTIONS="--vnet $VNET_NAME --subnet producers-subnet"

source ../simulator/run-generator.sh

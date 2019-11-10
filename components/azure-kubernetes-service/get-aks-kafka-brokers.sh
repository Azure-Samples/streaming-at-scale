#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "reading Kafka Broker IP from AKS"
kafka_ip=$(kubectl get services -n kafka my-cluster-kafka-external-bootstrap -o=jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}')

export KAFKA_BROKERS="$kafka_ip:9094"
export KAFKA_SECURITY_PROTOCOL=PLAINTEXT
export KAFKA_SASL_MECHANISM=
export KAFKA_SASL_JAAS_CONFIG=
export KAFKA_SASL_JAAS_CONFIG_DATABRICKS=

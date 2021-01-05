#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "reading Kafka Broker IP from AKS"
echo "NB: the service may take up to around 10 minutes to start."
TIMEOUT=120
for i in $(seq 1 $TIMEOUT); do
  if kafka_ip=$(kubectl --context $AKS_CLUSTER get services -n kafka $PREFIX-kafka-external-bootstrap -o=jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'); then
    if [ "$kafka_ip" != "" ]; then
      break
    fi
    echo "Broker deployed but IP not yet available. Retrying..."
  else
    echo "Broker not yet deployed. Retrying..."
  fi
  sleep 10
done
if [ "$kafka_ip" == "" ]; then
  echo "Could not find Kafka IP"
  exit 1
fi


export KAFKA_BROKERS="$kafka_ip:9094"
export KAFKA_SECURITY_PROTOCOL=PLAINTEXT
export KAFKA_SASL_MECHANISM=
export KAFKA_SASL_USERNAME=
export KAFKA_SASL_PASSWORD=
export KAFKA_SASL_JAAS_CONFIG=
export KAFKA_SASL_JAAS_CONFIG_DATABRICKS=

echo ". Broker: $KAFKA_BROKERS"

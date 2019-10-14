#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "getting HDInsight Ambari endpoint..."
endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

echo "reading Kafka Broker IPs from HDInsight Ambari..."
kafka_hostnames=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -G https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/services/KAFKA/components/KAFKA_BROKER | jq -r '["\(.host_components[].HostRoles.host_name)"] | join(" ")')
# Convert Kafka broker hostnames to IP addresses, since ACI doesn't support internal name resolution currently
# (https://docs.microsoft.com/en-us/azure/container-instances/container-instances-vnet#unsupported-networking-scenarios)
kafka_brokers=""
for host in $kafka_hostnames; do
    host_ip=$(curl -fsS -u admin:"$HDINSIGHT_PASSWORD" -G https://$endpoint/api/v1/clusters/$HDINSIGHT_NAME/hosts/$host | jq -r .Hosts.ip)
    kafka_brokers="$kafka_brokers,$host_ip:9092"
done

#remove initial comma from string
export KAFKA_BROKERS=${kafka_brokers:1}
export KAFKA_SECURITY_PROTOCOL=PLAINTEXT
export KAFKA_SASL_MECHANISM=
export KAFKA_SASL_JAAS_CONFIG=
export KAFKA_SASL_JAAS_CONFIG_DATABRICKS=

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'Determining Flink cluster UI'

cluster_pool_id=$(az resource show -g $RESOURCE_GROUP -n $HDINSIGHT_AKS_NAME --resource-type microsoft.hdinsight/clusterPools --query id -o tsv)
cluster_fqdn=$(az resource show --ids $cluster_pool_id/clusters/${HDINSIGHT_AKS_RESOURCE_PREFIX}flinkcluster --query properties.clusterProfile.connectivityProfile.web.fqdn -o tsv)

echo 'Preparing Flink Job JAR'

jar_name=flink-kafka-consumer-$FLINK_JOBTYPE.jar
cp "../components/apache-flink/flink-kafka-consumer/target/assembly/$jar_name" flink-job.jar
cat << EOF > params.properties
parallelism=$FLINK_PARALLELISM
kafka.in.topic=$KAFKA_TOPIC
kafka.in.bootstrap.servers=$KAFKA_IN_LISTEN_BROKERS
kafka.in.request.timeout.ms=60000
kafka.in.sasl.mechanism=$KAFKA_IN_LISTEN_SASL_MECHANISM
kafka.in.security.protocol=$KAFKA_IN_LISTEN_SECURITY_PROTOCOL
kafka.in.sasl.jaas.config=$KAFKA_IN_LISTEN_JAAS_CONFIG
kafka.in.group.id=$PREFIX
kafka.out.topic=$KAFKA_OUT_TOPIC
kafka.out.bootstrap.servers=$KAFKA_OUT_SEND_BROKERS
kafka.out.request.timeout.ms=60000
kafka.out.sasl.mechanism=$KAFKA_OUT_SEND_SASL_MECHANISM
kafka.out.security.protocol=$KAFKA_OUT_SEND_SECURITY_PROTOCOL
kafka.out.sasl.jaas.config=$KAFKA_OUT_SEND_JAAS_CONFIG
EOF

zip -g flink-job.jar params.properties

echo "The Job JAR must be"
echo "Flink UI: https://$cluster_fqdn"
echo "Job JAR: flink-job.jar"

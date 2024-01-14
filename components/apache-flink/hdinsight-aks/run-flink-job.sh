#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'Preparing Flink Job JAR'

base_jar=flink-kafka-consumer-$FLINK_JOBTYPE.jar
mkdir -p target
jar_name=$FLINK_JOBTYPE.jar
jar_path=target/$jar_name

cp "../components/apache-flink/flink-kafka-consumer/target/assembly/$base_jar" $jar_path

main_class=$(unzip -p target/simple-relay.jar META-INF/MANIFEST.MF | grep ^Main-Class:  |awk '{print $2}' RS='\r\n')

cat << EOF > params.properties
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

zip -g $jar_path params.properties
rm params.properties

echo 'uploading Flink job jar'

jobname=$(uuidgen | tr A-Z a-z)
jarname="$jobname.jar"

# if false; then
az storage blob upload --account-name "$HDINSIGHT_AKS_RESOURCE_PREFIX"store -c container1 \
    -n $jarname -f $jar_path \
    --overwrite \
    -o tsv >> log.txt
#fi

echo 'running Flink job'

cluster_resource=$(az resource show -g $RESOURCE_GROUP -n $HDINSIGHT_AKS_NAME --resource-type microsoft.hdinsight/clusterPools --api-version 2021-09-15-preview -o tsv --query id)
az rest --method POST --url "https://management.azure.com$cluster_resource/clusters/$HDINSIGHT_CLUSTER_NAME/runJob?api-version=2023-06-01-preview" \
--body '{
    "properties": {
        "jobType": "FlinkJob",
        "jobName": "'$jobname'",
        "action": "NEW",
        "jobJarDirectory": "abfs://container1@'$HDINSIGHT_AKS_RESOURCE_PREFIX'store.dfs.core.windows.net/",
        "jarName": "'$jarname'",
        "entryClass": "'$main_class'",
        "flinkConfiguration": {
            "parallelism": "'$FLINK_PARALLELISM'"
        }
    }
}'

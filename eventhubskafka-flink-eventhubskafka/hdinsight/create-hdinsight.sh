#!/bin/bash

set -euo pipefail

echo 'creating HDInsight cluster'
echo ". name: $HDINSIGHT_NAME"

source ../components/azure-common/create-virtual-network.sh
source ../components/azure-monitor/create-log-analytics.sh

az hdinsight create -t hadoop -g $RESOURCE_GROUP -n $HDINSIGHT_NAME \
  -p "$HDINSIGHT_PASSWORD" \
  --version 4.0 \
  --zookeepernode-size Standard_D2_V2 \
  --headnode-size Standard_E2_V3 \
  --workernode-size $HDINSIGHT_WORKER_SIZE --workernode-count $HDINSIGHT_WORKERS \
  --vnet-name $VNET_NAME --subnet ingestion-subnet \
  --storage-account $AZURE_STORAGE_ACCOUNT \
  -o tsv >> log.txt

echo 'Enable HDInsight monitoring'
echo ". workspace: $LOG_ANALYTICS_WORKSPACE"

az hdinsight monitor enable -g $RESOURCE_GROUP -n $HDINSIGHT_NAME --workspace $LOG_ANALYTICS_WORKSPACE \
  -o tsv >> log.txt

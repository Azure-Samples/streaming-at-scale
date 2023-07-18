#!/bin/bash

set -euo pipefail

# Get ID of current user
userId=$(az ad signed-in-user show --query id -o tsv)

echo 'creating HDInsight cluster'
echo ". name: $HDINSIGHT_AKS_NAME"

if ! az resource show -g $RESOURCE_GROUP -n $HDINSIGHT_AKS_NAME --resource-type microsoft.hdinsight/clusterPools -o none 2>/dev/null ; then
  az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file "../components/apache-flink/hdinsight-aks/OneClickF.json" \
    --parameters \
      clusterpoolName=$HDINSIGHT_AKS_NAME \
      resourcePrefix=$HDINSIGHT_AKS_RESOURCE_PREFIX \
      clusterVMSize=$HDINSIGHT_AKS_WORKER_SIZE \
      userObjectId=$userId \
    -o tsv >> log.txt
fi
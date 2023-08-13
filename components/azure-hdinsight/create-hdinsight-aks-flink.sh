#!/bin/bash

set -euo pipefail

# Get ID of current user
userId=$(az ad signed-in-user show --query id -o tsv)


if ! az resource show -g $RESOURCE_GROUP -n $HDINSIGHT_AKS_NAME --resource-type microsoft.hdinsight/clusterPools --api-version 2021-09-15-preview -o none 2>/dev/null ; then
  echo "getting Subnet ID"
  subnet_id=$(az network vnet subnet show -g $RESOURCE_GROUP -n streaming-subnet --vnet-name $VNET_NAME --query id -o tsv)

  echo "getting Log Analytics workspace ID"
  analytics_ws_resourceId=$(az resource show -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --resource-type Microsoft.OperationalInsights/workspaces --query id -o tsv)

  echo 'creating HDInsight cluster'
  echo ". name: $HDINSIGHT_AKS_NAME"

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

#!/bin/bash

set -euo pipefail

echo 'getting EH shared access key'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryKey" -o tsv`

echo 'creating stream analytics job'
echo ". name: $PROC_JOB_NAME"
az group deployment create \
  --name $PROC_JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --template-file stream-analytics-job-$STREAM_ANALYTICS_JOBTYPE-arm-template.json \
  --parameters \
    streamingJobName=$PROC_JOB_NAME \
    eventHubNamespace=$EVENTHUB_NAMESPACE \
    eventHubKey=$EVENTHUB_KEY \
    eventHubName=$EVENTHUB_NAME \
    eventHubNameOut=$EVENTHUB_NAME_OUT \
    eventHubConsumerGroupName=$EVENTHUB_CG \
    streamingUnits=$PROC_STREAMING_UNITS \
    eventHubPartitionKeyOut=PartitionId \
  -o tsv >> log.txt

echo 'done creating stream analytics job, check log.txt for any errors'

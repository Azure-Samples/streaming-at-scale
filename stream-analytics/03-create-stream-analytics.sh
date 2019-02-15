#!/bin/bash

echo 'getting EH shared access key'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryKey" -o tsv`

echo "getting cosmosdb master key"
COSMOSDB_MASTER_KEY=`az cosmosdb list-keys -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryMasterKey" -o tsv`

echo 'creating stream analytics job'
echo ". name: $PROC_JOB_NAME"
az group deployment create \
  --name $PROC_JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --template-file streamanalyticsjob.json \
  --parameters streamingJobName=$PROC_JOB_NAME eventHubNamespace=$EVENTHUB_NAMESPACE eventHubKey=$EVENTHUB_KEY eventHubName=$EVENTHUB_NAME eventHubConsumerGroupName=$EVENTHUB_CG streamingUnits=$PROC_STREAMING_UNITS cosmosdbAccountId=$COSMOSDB_SERVER_NAME cosmosdbAccountKey=$COSMOSDB_MASTER_KEY cosmosdbDatabase=$COSMOSDB_DATABASE_NAME cosmosdbCollectionName=$COSMOSDB_COLLECTION_NAME cosmosdbPartitionKey=deviceId cosmosdbDocumentId='' \
  -o tsv >> log.txt

echo 'done creating stream analytics job, check log.txt for any errors'

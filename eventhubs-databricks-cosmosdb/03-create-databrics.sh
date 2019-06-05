#!/bin/bash

echo 'getting EH shared access key'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name RootManageSharedAccessKey --query "primaryKey" -o tsv`

echo "getting cosmosdb master key"
COSMOSDB_MASTER_KEY=`az cosmosdb list-keys -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryMasterKey" -o tsv`

echo 'creating databricks workspace'
echo ". name: $PROC_JOB_NAME"
az group deployment create \
  --name $PROC_JOB_NAME \
  --resource-group $RESOURCE_GROUP \
  --template-file arm/databricks.arm.json \
  --parameters \
    workspaceName=$ADB_WORKSPACE \
    location=$LOCATION \
    tier=standard \
  -o tsv >> log.txt





 

  
#!/bin/bash

echo "getting cosmosdb master key"
COSMOSDB_MASTER_KEY=`az cosmosdb keys list -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --query "primaryMasterKey" -o tsv`

echo 'adding app settings for connection strings'
echo ". function: $PROC_FUNCTION_APP_NAME"

echo ". CosmosDBDatabaseName: $COSMOSDB_DATABASE_NAME"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings CosmosDBDatabaseName="$COSMOSDB_DATABASE_NAME" \
    -o tsv >> log.txt

echo ". CosmosDBCollectionName: $COSMOSDB_COLLECTION_NAME"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings CosmosDBCollectionName="$COSMOSDB_COLLECTION_NAME" \
    -o tsv >> log.txt

COSMOSDB_CONNSTR="AccountEndpoint=https://$COSMOSDB_SERVER_NAME.documents.azure.com:443/;AccountKey=$COSMOSDB_MASTER_KEY;"
echo ". CosmosDBConnectionString: $COSMOSDB_CONNSTR"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings CosmosDBConnectionString=$COSMOSDB_CONNSTR \
    -o tsv >> log.txt


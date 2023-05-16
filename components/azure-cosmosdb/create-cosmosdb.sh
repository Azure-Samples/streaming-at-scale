#!/bin/bash

set -euo pipefail

# Using ARM template as AZ CLI does not allow setting unique keys, https://github.com/Azure/azure-cli/issues/6206

echo 'creating Cosmos DB instance'
echo ". account name: $COSMOSDB_SERVER_NAME"
echo ". database name: $COSMOSDB_DATABASE_NAME"
echo ". collection name: $COSMOSDB_COLLECTION_NAME"

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file ../components/azure-cosmosdb/cosmosdb-arm-template.json \
  --parameters \
    accountName=$COSMOSDB_SERVER_NAME \
    databaseName=$COSMOSDB_DATABASE_NAME \
    containerName=$COSMOSDB_COLLECTION_NAME \
    throughput=$COSMOSDB_RU \
  -o tsv >> log.txt

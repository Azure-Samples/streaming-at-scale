#!/bin/bash

echo 'creating cosmosdb account'
echo ". name: $COSMOSDB_SERVER_NAME"
az cosmosdb create -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME \
-o tsv >> log.txt

echo 'creating cosmosdb database'
echo ". name: $COSMOSDB_DATABASE_NAME"
az cosmosdb database create -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --db-name $COSMOSDB_DATABASE_NAME \
-o tsv >> log.txt

echo 'creating cosmosdb collection'
echo ". name: $COSMOSDB_COLLECTION_NAME"
az cosmosdb collection create -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME \
-d $COSMOSDB_DATABASE_NAME --collection-name $COSMOSDB_COLLECTION_NAME \
--partition-key-path "/eventData/eventId" --throughput 20000 \
--indexing-policy '{"indexingMode": "none"}' \
-o tsv >> log.txt


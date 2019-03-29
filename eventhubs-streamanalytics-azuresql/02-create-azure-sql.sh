#!/bin/bash

echo 'creating sql server account'
echo ". name: $COSMOSDB_SERVER_NAME"
SERVER_EXISTS=`az cosmosdb check-name-exists -n $COSMOSDB_SERVER_NAME -o tsv`
if [ $SERVER_EXISTS == "false" ]; then
    az cosmosdb create -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME \
    -o tsv >> log.txt
fi

echo 'creating sql database'
echo ". name: $COSMOSDB_DATABASE_NAME"
DB_EXISTS=`az cosmosdb database exists -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --db-name $COSMOSDB_DATABASE_NAME -o tsv`
if [ $DB_EXISTS == "false" ]; then
    az cosmosdb database create -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --db-name $COSMOSDB_DATABASE_NAME \
    -o tsv >> log.txt
fi

echo 'creating cosmosdb collection'
echo ". name: $COSMOSDB_COLLECTION_NAME"
COLLECTION_EXISTS=`az cosmosdb collection exists -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME --db-name $COSMOSDB_DATABASE_NAME --collection-name $COSMOSDB_COLLECTION_NAME -o tsv`
if [ $COLLECTION_EXISTS == "false" ]; then
    az cosmosdb collection create -g $RESOURCE_GROUP -n $COSMOSDB_SERVER_NAME \
    -d $COSMOSDB_DATABASE_NAME --collection-name $COSMOSDB_COLLECTION_NAME \
    --partition-key-path "/deviceId" --throughput $COSMOSDB_RU \
    --indexing-policy @index-policy.json \
    -o tsv >> log.txt
fi

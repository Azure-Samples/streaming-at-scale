#!/bin/bash

if [ -z $1 ]; then
    echo "usage: $0 <deployment-name>"
    echo "eg: $0 test1"
    exit 1
fi

export PREFIX=$1
export RESOURCE_GROUP=$PREFIX
export LOCATION=eastus

# remove log.txt if exists
rm log.txt -f

echo
echo "Streaming at Scale with CosmosDB"
echo "================================"
echo
echo "deployment started..."
echo

echo "***** setting up common resources"

    ../_common/01-create-resource-group.sh

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    ../_common/02-create-storage-account.sh

echo 

echo "***** setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"ingest"
    export EVENTHUB_PARTITIONS=32
    export EVENTHUB_NAME=$PREFIX"ingest-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="cosmos"

    ./01-create-event-hub.sh

echo

echo "***** setting up TEST clients"

    ./02-setup-test-clients.sh

echo

echo "***** setting up DATABASE"

    export COSMOSDB_SERVER_NAME=$PREFIX"cosmosdb" 
    export COSMOSDB_DATABASE_NAME="streaming"
    export COSMOSDB_COLLECTION_NAME="rawdata"

    ./03-create-cosmosdb.sh
echo

echo "***** setting up PROCESSING"

    export PROC_FUNCTION_APP_NAME=$PREFIX"process"
    export PROC_FUNCTION_NAME=StreamingProcessor
    export PROC_PACKAGE_FOLDER=.
    export PROC_PACKAGE_TARGET=CosmosDB
    export PROC_PACKAGE_NAME=$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET.zip
    export PROC_PACKAGE_PATH=$PROC_PACKAGE_FOLDER/$PROC_PACKAGE_NAME

    ./04-create-processing-function.sh
    ./05-configure-processing-function-cosmosdb.sh

echo

echo "***** starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    ./06-run-clients.sh

echo

echo "***** done"
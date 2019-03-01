#!/bin/bash

set -e

if [ -z $1 ]; then
    echo "usage: $0 <deployment-name> <steps>"
    echo "eg: $0 test1"    
    exit 1
fi

on_error() {
    set +e
    echo "There was an error, execution halted" >&2
    exit 1
}

trap on_error ERR

export PREFIX=$1
export RESOURCE_GROUP=$PREFIX
export LOCATION=eastus

# 10000 messages/sec
# export EVENTHUB_PARTITIONS=12
# export EVENTHUB_CAPACITY=12
# export PROC_FUNCTION=Test0
# export PROC_FUNCTION_SKU=P2v2
# export PROC_FUNCTION_WORKERS=12
# export COSMOSDB_RU=80000
# export TEST_CLIENTS=20

# 5500 messages/sec
# export EVENTHUB_PARTITIONS=8
# export EVENTHUB_CAPACITY=8
# export PROC_FUNCTION=Test0
# export PROC_FUNCTION_SKU=P1v2
# export PROC_FUNCTION_WORKERS=8
# export COSMOSDB_RU=40000
# export TEST_CLIENTS=10

# 1000 messages/sec
export EVENTHUB_PARTITIONS=2
export EVENTHUB_CAPACITY=2
export PROC_FUNCTION=Test0
export PROC_FUNCTION_SKU=P2v2
export PROC_FUNCTION_WORKERS=2
export COSMOSDB_RU=20000
export TEST_CLIENTS=2

export STEPS=$2

if [ -z $STEPS ]; then  
    export STEPS="CIDPT"    
fi

# remove log.txt if exists
rm -f log.txt

echo
echo "Streaming at Scale: EventHubs + Functions + CosmosDB "
echo "======================================================"
echo

echo "steps to be executed: $STEPS"
echo

echo "configuration: "
echo "EventHubs  => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo "Function   => Name: $PROC_FUNCTION, SKU: $PROC_FUNCTION_SKU, Workers: $PROC_FUNCTION_WORKERS"
echo "CosmosDB   => RU: $COSMOSDB_RU"
echo "Locusts    => $TEST_CLIENTS"
echo

echo "checking prerequisistes..."

HAS_AZ=`command -v az`
if [ -z HAS_AZ ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

HAS_PY3=`command -v python3`
if [ -z HAS_PY3 ]; then
    echo "python3 not found"
    echo "please install it as it is needed by the script"
    exit 1
fi

HAS_ZIP=`command -v zip`
if [ -z HAS_ZIP ]; then
    echo "zip not found"
    echo "please install it as it is needed by the script"
    exit 1
fi

HAS_DOTNET=`command -v dotnet`
if [ -z HAS_DOTNET ]; then
    echo "dotnet not found"
    echo "please install it as it is needed by the script"
    exit 1
fi

echo "deployment started..."
echo

echo "***** [C] setting up common resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o`    
    if [ ! -z $RUN ]; then
        ../_common/01-create-resource-group.sh
        ../_common/02-create-storage-account.sh
    fi
echo 

echo "***** [I] setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"ingest"    
    export EVENTHUB_NAME=$PREFIX"ingest-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="cosmos"

    RUN=`echo $STEPS | grep I -o`
    if [ ! -z $RUN ]; then
        ./01-create-event-hub.sh
    fi
echo

echo "***** [D] setting up DATABASE"

    export COSMOSDB_SERVER_NAME=$PREFIX"cosmosdb" 
    export COSMOSDB_DATABASE_NAME="streaming"
    export COSMOSDB_COLLECTION_NAME="rawdata"

    RUN=`echo $STEPS | grep D -o`
    if [ ! -z $RUN ]; then
        ./02-create-cosmosdb.sh
    fi
echo

echo "***** [P] setting up PROCESSING"

    export PROC_FUNCTION_APP_NAME=$PREFIX"process"
    export PROC_FUNCTION_NAME=StreamingProcessor
    export PROC_PACKAGE_FOLDER=.
    export PROC_PACKAGE_TARGET=CosmosDB    
    export PROC_PACKAGE_NAME=$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET.zip
    export PROC_PACKAGE_PATH=$PROC_PACKAGE_FOLDER/$PROC_PACKAGE_NAME

    RUN=`echo $STEPS | grep P -o`
    if [ ! -z $RUN ]; then
        ./03-create-processing-function.sh
        ./04-configure-processing-function-cosmosdb.sh
    fi
echo

echo "***** [T] starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o`
    if [ ! -z $RUN ]; then
        ./05-run-clients.sh
    fi
echo

echo "***** done"

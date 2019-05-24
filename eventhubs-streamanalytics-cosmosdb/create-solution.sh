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
    echo "Error at line $1"
    exit 1
}

trap 'on_error $LINENO' ERR

export PREFIX=$1
export RESOURCE_GROUP=$PREFIX
export LOCATION=westus

# 10000 messages/sec
# export EVENTHUB_PARTITIONS=12
# export EVENTHUB_CAPACITY=12
# export PROC_JOB_NAME=streamingjob
# export PROC_STREAMING_UNITS=72
# export COSMOSDB_RU=100000
# export TEST_CLIENTS=20

# 5500 messages/sec
# export EVENTHUB_PARTITIONS=8
# export EVENTHUB_CAPACITY=6
# export PROC_JOB_NAME=streamingjob
# export PROC_STREAMING_UNITS=24
# export COSMOSDB_RU=40000
# export TEST_CLIENTS=10

# 1000 messages/sec
export EVENTHUB_PARTITIONS=2
export EVENTHUB_CAPACITY=2
export PROC_JOB_NAME=streamingjob
export PROC_STREAMING_UNITS=6
export COSMOSDB_RU=10000
export TEST_CLIENTS=2

# Use provided steps or default to CIDPT
export STEPS="CIDPT"
if [ ! -z ${2+x} ]; then
    export STEPS=$2
fi

# remove log.txt if exists
rm -f log.txt

echo "Checking prerequisites..."

HAS_AZ=$(command -v az)
if [ -z HAS_AZ ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

echo
echo "Streaming at Scale with Stream Analytics and CosmosDB"
echo "================================"
echo

echo "steps to be executed: $STEPS"
echo

echo "configuration: "
echo "EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo "StreamAnalytics => Name: $PROC_JOB_NAME, SU: $PROC_STREAMING_UNITS"
echo "CosmosDB        => RU: $COSMOSDB_RU"
echo "Locusts         => $TEST_CLIENTS"
echo

echo "deployment started..."
echo

echo "***** [C] setting up COMMON resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z $RUN ]; then
        ../_common/01-create-resource-group.sh
        ../_common/02-create-storage-account.sh
    fi
echo 

echo "***** [I] setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"    
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="cosmos"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z $RUN ]; then
        ./01-create-event-hub.sh
    fi
echo

echo "***** [D] setting up DATABASE"

    export COSMOSDB_SERVER_NAME=$PREFIX"cosmosdb" 
    export COSMOSDB_DATABASE_NAME="streaming"
    export COSMOSDB_COLLECTION_NAME="rawdata"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z $RUN ]; then
        ./02-create-cosmosdb.sh
    fi
echo

echo "***** [P] setting up PROCESSING"

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z $RUN ]; then
        ./03-create-stream-analytics.sh
    fi
echo

echo "***** [T] starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z $RUN ]; then
        ./04-run-clients.sh
    fi
echo

echo "***** done"

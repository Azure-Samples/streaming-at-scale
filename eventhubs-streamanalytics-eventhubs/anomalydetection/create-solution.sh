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
export LOCATION=eastus

# 10000 messages/sec
export EVENTHUB_PARTITIONS=12
export EVENTHUB_CAPACITY=10
export PROC_JOB_NAME=streamingjob
export PROC_STREAMING_UNITS=12
export TEST_CLIENTS=20

# 5500 messages/sec
# export EVENTHUB_PARTITIONS=6
# export EVENTHUB_CAPACITY=6
# export PROC_JOB_NAME=streamingjob
# export PROC_STREAMING_UNITS=6
# export TEST_CLIENTS=10

# 1000 messages/sec
# export EVENTHUB_PARTITIONS=2
# export EVENTHUB_CAPACITY=2
# export PROC_JOB_NAME=streamingjob
# export PROC_STREAMING_UNITS=3
# export TEST_CLIENTS=2

export STEPS=$2
if [ -z $PROC_STREAMING_UNITS ]; then  
    let "PROC_STREAMING_UNITS=EVENTHUB_PARTITIONS"
fi

if [ -z $STEPS ]; then  
    export STEPS="CIDPT"    
fi

# remove log.txt if exists
rm -f log.txt

echo
echo "Streaming at Scale with Stream Analytics and Event Hubs with Anomaly Detection scenario"
echo "================================"
echo

echo "steps to be executed: $STEPS"
echo

echo "configuration: "
echo "EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo "StreamAnalytics => Name: $PROC_JOB_NAME, SU: $PROC_STREAMING_UNITS"
echo "Locusts         => $TEST_CLIENTS"
echo

echo "Checking prerequisites..."

HAS_AZ=`command -v az`
if [ -z HAS_AZ ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

echo "deployment started..."
echo

echo "***** [C] setting up common resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z $RUN ]; then
        ../../_common/01-create-resource-group.sh
        ../../_common/02-create-storage-account.sh
    fi
echo 

echo "***** [I] setting up INGESTION AND EGRESS EVENT HUBS"
    
    export EVENTHUB_NAMESPACE=$PREFIX"ingest"
    export EVENTHUB_NAME=$PREFIX"ingest-"$EVENTHUB_PARTITIONS
    export EVENTHUB_NAME_OUT=$PREFIX"out-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="asa"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z $RUN ]; then
        ./01-create-event-hub.sh
    fi
echo

echo "***** [P] setting up PROCESSING"

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z $RUN ]; then
        ./02-create-stream-analytics.sh
    fi
echo

echo "***** [T] starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z $RUN ]; then
        ./03-run-clients.sh
    fi
echo

echo "***** done"

#!/bin/bash

set -euo pipefail

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
# export EVENTHUB_PARTITIONS=12
# export EVENTHUB_CAPACITY=12
# export PROC_JOB_NAME=streamingjob
# export PROC_STREAMING_UNITS=12
# export SQL_SKU=S9
# export SQL_TABLE_KIND="rowstore" # or "columnstore"
# export TEST_CLIENTS=20

# 5500 messages/sec
# export EVENTHUB_PARTITIONS=8
# export EVENTHUB_CAPACITY=8
# export PROC_JOB_NAME=streamingjob
# export PROC_STREAMING_UNITS=6
# export SQL_SKU=S7
# export SQL_TABLE_KIND="rowstore" # or "columnstore"
# export TEST_CLIENTS=10

# 1000 messages/sec
export EVENTHUB_PARTITIONS=2
export EVENTHUB_CAPACITY=2
export PROC_JOB_NAME=streamingjob
export PROC_STREAMING_UNITS=3
export SQL_SKU=S3
export SQL_TABLE_KIND="rowstore" # or "columnstore"
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

HAS_PY3=$(command -v python3)
if [ -z HAS_PY3 ]; then
    echo "python3 not found"
    echo "please install it as it is needed by the script"
    exit 1
fi

declare TABLE_SUFFIX=""
case $SQL_TABLE_KIND in
    rowstore)
        TABLE_SUFFIX=""
        ;;
    columnstore)
        TABLE_SUFFIX="_cs"
        ;;
    *)
        echo "SQL_TABLE_KIND must be set to 'rowstore' or 'columnstore'"
        echo "please install it as it is needed by the script"
        exit 1
        ;;
esac

echo
echo "Streaming at Scale with Stream Analytics and AzureSQL"
echo "====================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration:"
echo "EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo "StreamAnalytics => Name: $PROC_JOB_NAME, SU: $PROC_STREAMING_UNITS"
echo "Azure SQL       => SKU: $SQL_SKU, TABLE_TYPE: $SQL_TABLE_KIND"
echo "Locusts         => $TEST_CLIENTS"
echo

echo "Deployment started..."
echo

echo "***** [C] Setting up COMMON resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z $RUN ]; then
        ../_common/01-create-resource-group.sh
        ../_common/02-create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"    
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="azuresql"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z $RUN ]; then
        ./01-create-event-hub.sh
    fi
echo

echo "***** [D] Setting up DATABASE"

    export SQL_SERVER_NAME=$PREFIX"sql" 
    export SQL_DATABASE_NAME="streaming"    

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z $RUN ]; then
        ./02-create-azure-sql.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    export SQL_TABLE_NAME="rawdata$TABLE_SUFFIX"

    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z $RUN ]; then
        ./03-create-stream-analytics.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z $RUN ]; then
        ./04-run-clients.sh
    fi
echo

echo "***** Done"

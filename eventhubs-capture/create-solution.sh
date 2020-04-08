#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

if [ -z $1 ]; then
    echo "usage: $0 <deployment-name> <steps>"
    echo "eg: $0 test1"    
    exit 1
fi

export PREFIX=$1
export RESOURCE_GROUP=$PREFIX
export LOCATION=eastus

# 10000 messages/sec
# export EVENTHUB_PARTITIONS=12
# export EVENTHUB_CAPACITY=12
# export SIMULATOR_INSTANCES=5

# 5000 messages/sec
# export EVENTHUB_PARTITIONS=8
# export EVENTHUB_CAPACITY=8
# export SIMULATOR_INSTANCES=3

# 1000 messages/sec
export EVENTHUB_PARTITIONS=2
export EVENTHUB_CAPACITY=2
export SIMULATOR_INSTANCES=1

export STEPS=${2:-CITD}

# remove log.txt if exists
rm -f log.txt

echo
echo "Streaming at Scale with EventHubs Capture"
echo "========================================="
echo

echo "steps to be executed: $STEPS"
echo

echo "checking prerequisistes..."

source ../assert/has-local-az.sh
source ../assert/has-local-jq.sh

echo "deployment started..."
echo

echo "***** [C] setting up common resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-common/create-resource-group.sh
        source ../components/azure-storage/create-storage-account.sh
    fi
echo 

echo "***** [I] setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"ingest"    
    export EVENTHUB_NAME=$PREFIX"ingest-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CAPTURE=True

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/create-event-hub.sh
    fi
echo

echo "***** [T] starting up TEST clients"    
    RUN=`echo $STEPS | grep T -o || true`
    export TESTTYPE=$SIMULATOR_INSTANCES
    if [ ! -z "$RUN" ]; then
        source ../simulator/run-generator-eventhubs.sh
    fi
echo

echo "***** [D] Running Apache Drill"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        echo "getting storage key"
        export AUTHKEY=`az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value"`

        echo "the following configuration will be injected into Apache Drill"        
        echo "{"
        echo "\"connection\": \"wasbs://eventhubs@$AZURE_STORAGE_ACCOUNT.blob.core.windows.net\""
        echo "\"config\": { \"fs.azure.account.key.$AZURE_STORAGE_ACCOUNT.blob.core.windows.net\": \"$AUTHKEY\" }"
        echo "}"
        ADST=$(cat ../components/apache-drill/azure-data-source.json)
        ADS=`echo "$ADST" | sed 's/CONTAINER/eventhubs/g' | sed "s/STORAGE_ACCOUNT_NAME/$AZURE_STORAGE_ACCOUNT/g" | sed "s|AUTHENTICATION_KEY|$AUTHKEY|g"`
        
        echo "running Apache Drill using Docker"
        docker run -it --rm -d --name drill -p 8047:8047 -t yorek/apache-drill-azure-blob /bin/bash
        sleep 20

        echo "injecting data store configuration"
        curl -fsL -X POST -H "Content-Type: application/json" -d "$ADS" http://localhost:8047/storage/azure.json                
        
        echo "done"
        echo "==> look in ../components/apache-drill folder for sample queries"

        echo "Apache Drill can be access via Web UI:"
        echo "==> http://localhost:8047"
        echo "or by console:"
        echo "==> docker attach drill"
    fi

echo "***** done"

#!/bin/bash

#set -e

if [ -z $1 ]; then
    echo "usage: $0 <deployment-name> <steps>"
    echo "eg: $0 test1"    
    exit 1
fi

export PREFIX=$1
export RESOURCE_GROUP=$PREFIX
export LOCATION=eastus

# 10000 messages/sec
# export EVENTHUB_PARTITIONS=32
# export EVENTHUB_CAPACITY=12
# export PROC_FUNCTION_WORKERS=24
# export TEST_CLIENTS=20

# 5500 messages/sec
# export EVENTHUB_PARTITIONS=32
# export EVENTHUB_CAPACITY=10
# export PROC_FUNCTION_WORKERS=16
# export TEST_CLIENTS=10

# 1000 messages/sec
export EVENTHUB_PARTITIONS=16
export EVENTHUB_CAPACITY=2
export TEST_CLIENTS=2

export STEPS=$2

if [ -z $STEPS ]; then  
    export STEPS="CITH"    
fi

# remove log.txt if exists
rm -f log.txt

echo
echo "Streaming at Scale with EventHubs Capture"
echo "========================================="
echo

echo "steps to be executed: $STEPS"
echo

echo "checking prerequisistes..."
HAS_AZ=`command -v az`
HAS_PY3=`command -v python3`

if [ -z HAS_AZ ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

if [ -z HAS_PY3 ]; then
    echo "python3 not found"
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

    RUN=`echo $STEPS | grep I -o`
    if [ ! -z $RUN ]; then
        ./01-create-event-hub.sh
    fi
echo

echo "***** [T] starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o`
    if [ ! -z $RUN ]; then
        ./02-run-clients.sh
    fi
echo

echo "***** [H] Generating HDFS Azure Blob Storage connection info"

    RUN=`echo $STEPS | grep H -o`
    if [ ! -z $RUN ]; then
        export AUTHKEY=`az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value"`

        echo
        echo "Put the following connection string in your Apache Drill Azure Storge Data Source ""connection"" configuration"
        echo "(file is in ./drill/azure-data-source.json)"
        echo "wasbs://eventhubs@$AZURE_STORAGE_ACCOUNT.blob.core.windows.net"
        
        echo
        echo "Put the following key-value pair into the ""config"" section of your Apache Drill Azure Storge Data Source"
        echo "(file is in ./drill/azure-data-source.json)"
        echo "\"fs.azure.account.key.$AZURE_STORAGE_ACCOUNT.blob.core.windows.net\": \"$AUTHKEY\""

        echo
        echo "You can now run Apache Drill"
        ADST=$(cat ./drill/azure-data-source.json)
        ADS=`echo "$ADST" | sed 's/CONTAINER/eventhub/g' | sed "s/STORAGE_ACCOUNT_NAME/$AZURE_STORAGE_ACCOUNT/g" | sed "s|AUTHENTICATION_KEY|$AUTHKEY|g"`
        docker run -it --rm -d --name drill -p 8047:8047 -t yorek/apache-drill-azure-blob /bin/bash
        sleep 20
        curl -X POST -H "Content-Type: application/json" -d "$ADS" http://localhost:8047/storage/azure.json                
        echo

        echo "select t.B.`deviceId`, t.B.`type`, t.B.`value` from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` limit 10) as t;"
        echo "select t.B.`deviceId`, t.B.`type`, AVG(t.B.`value`) as `value` from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_35_1.avro` limit 10) as t group by t.B.`deviceId`, t.B.`type`;"
        echo " select t.B.`deviceId`, t.B.`type`, AVG(t.B.`value`) as `value`, COUNT(t.B.deviceId) as ctn from (select convert_from(Body, 'JSON') as B from azure.`dmehct1ingest/dmehct1ingest-16/2018_10_02_23_01_*.avro`) as t group by t.B.`deviceId`, t.B.`type` order by ctn limit 10;"
        echo "http://localhost:8047"
        echo "docker attach drill"
    fi

echo "***** done"

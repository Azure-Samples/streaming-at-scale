#!/bin/bash

if [ -z $1 ]; then
    echo "usage: $0 <deployment-name> <steps>"
    echo "eg: $0 test1"    
    exit 1
fi

export PREFIX=$1
export RESOURCE_GROUP=$PREFIX
export LOCATION=eastus

export STEPS=$2

if [ -z $STEPS ]; then  
    export STEPS="CIT"    
fi

# remove log.txt if exists
rm -f log.txt

echo
echo "IoT Hub device to cloud message streaming at scale"
echo "=================================================="
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

echo "Install azure-cli-iot-ext"
az extension add --name azure-cli-iot-ext

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
    
    export IOTHUB_NAME=""
    export IOTHUB_SAS_TOKEN=""

    # RUN=`echo $STEPS | grep I -o`
    # if [ ! -z $RUN ]; then
    #     ./01-create-iot-hub.sh
    # fi
echo

#echo "***** [D] setting up DATABASE"
    # TODO : Uncomment below if database is required
    # export COSMOSDB_SERVER_NAME=$PREFIX"cosmosdb" 
    # export COSMOSDB_DATABASE_NAME="streaming"
    # export COSMOSDB_COLLECTION_NAME="rawdata"

    # RUN=`echo $STEPS | grep D -o`
    # if [ ! -z $RUN ]; then
    #     ./02-create-cosmosdb.sh
    # fi
#echo

#echo "***** [P] setting up PROCESSING"

    # TODO : Replace below with Azure function for IotHub
    # export PROC_FUNCTION_APP_NAME=$PREFIX"process"
    # export PROC_FUNCTION_NAME=StreamingProcessor
    # export PROC_PACKAGE_FOLDER=.
    # export PROC_PACKAGE_TARGET=CosmosDB
    # export PROC_PACKAGE_NAME=$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET.zip
    # export PROC_PACKAGE_PATH=$PROC_PACKAGE_FOLDER/$PROC_PACKAGE_NAME

    # RUN=`echo $STEPS | grep P -o`
    # if [ ! -z $RUN ]; then
    #     ./03-create-processing-function.sh
    #     ./04-configure-processing-function-cosmosdb.sh
    # fi
#echo

echo "***** [T] starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o`
    if [ ! -z $RUN ]; then
        ./05-run-clients.sh
    fi
echo

echo "***** done"

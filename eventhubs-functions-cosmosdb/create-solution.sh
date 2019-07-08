#!/bin/bash

set -euo pipefail

on_error() {
    set +e
    echo "There was an error, execution halted" >&2
    echo "Error at line $1"
    exit 1
}

trap 'on_error $LINENO' ERR

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-f <function-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=CIDPT"
    echo "    Possibile values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      D=DATABASE"
    echo "      P=PROCESSING"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "-t: test 1,5,10 thousands msgs/sec. Default=1"
    echo "-f: function to test. Default=Test0"    
    echo "-l: where to create the resources. Default=eastus"
    exit 1; 
}

export PREFIX=''
export LOCATION=''
export TESTTYPE=''
export STEPS=''
export PROC_FUNCTION=''

# Initialize parameters specified from command line
while getopts ":d:s:t:l:f:" arg; do
	case "${arg}" in
		d)
			PREFIX=${OPTARG}
			;;
		s)
			STEPS=${OPTARG}
			;;
		t)
			TESTTYPE=${OPTARG}
			;;
		l)
			LOCATION=${OPTARG}
			;;
        f)
			PROC_FUNCTION=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$PREFIX" ]]; then
	echo "Enter a name for this deployment."
	usage
fi

if [[ -z "$LOCATION" ]]; then
	export LOCATION="eastus"
fi

if [[ -z "$TESTTYPE" ]]; then
	export TESTTYPE="1"
fi

if [[ -z "$PROC_FUNCTION" ]]; then
	export PROC_FUNCTION="Test0"
fi

if [[ -z "$STEPS" ]]; then
	export STEPS="CIDPTM"
fi

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export EVENTHUB_PARTITIONS=20
    export EVENTHUB_CAPACITY=12
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=20
    export COSMOSDB_RU=100000 
    export TEST_CLIENTS=30
fi

# 5500 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=10
    export EVENTHUB_CAPACITY=6
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=10
    export COSMOSDB_RU=50000
    export TEST_CLIENTS=16
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=2
    export COSMOSDB_RU=20000
    export TEST_CLIENTS=3
fi

# last checks and variables setup
if [ -z "${TEST_CLIENTS+x}" ]; then
    usage
fi

case $PROC_FUNCTION in
    Test0)
        ;;
    Test1)
        ;;
    *)
        echo "PROC_FUNCTION (option '-f') must be set to 'Test0' or 'Test1'"
        echo "Check documentation on GitHub"
        usage
esac

export RESOURCE_GROUP=$PREFIX

# remove log.txt if exists
rm -f log.txt

echo "Checking pre-requisites..."

HAS_AZ=$(command -v az)
if [ -z HAS_AZ ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

HAS_JQ=$(command -v jq)
if [ -z HAS_JQ ]; then
    echo "jq not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install jq"
    echo "or as described here:"
    echo "  https://stedolan.github.io/jq/download/"
    exit 1
fi

HAS_ZIP=$(command -v zip)
if [ -z HAS_ZIP ]; then
    echo "zip not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install zip"
    exit 1
fi

HAS_DOTNET=`command -v dotnet`
if [ -z HAS_DOTNET ]; then
    echo "dotnet SDK not found"
    echo "please install it as it is needed by the script"
    echo "https://dotnet.microsoft.com/download"
    exit 1
fi

echo
echo "Streaming at Scale with Azure Functions and CosmosDB"
echo "===================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". Function        => Name: $PROC_FUNCTION, SKU: $PROC_FUNCTION_SKU, Workers: $PROC_FUNCTION_WORKERS"
echo ". CosmosDB        => RU: $COSMOSDB_RU"
echo ". Locusts         => $TEST_CLIENTS"
echo

echo "Deployment started..."
echo

echo "***** [C] setting up COMMON resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`    
    if [ ! -z "$RUN" ]; then
        source ../components/azure-common/create-resource-group.sh
        source ../components/azure-storage/create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"    
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="cosmos"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/create-event-hub.sh
    fi
echo

echo "***** [D] Setting up DATABASE"

    export COSMOSDB_SERVER_NAME=$PREFIX"cosmosdb" 
    export COSMOSDB_DATABASE_NAME="streaming"
    export COSMOSDB_COLLECTION_NAME="rawdata"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-cosmosdb/create-cosmosdb.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export PROC_FUNCTION_APP_NAME=$PREFIX"process"
    export PROC_FUNCTION_NAME=StreamingProcessor
    export PROC_PACKAGE_FOLDER=.
    export PROC_PACKAGE_TARGET=CosmosDB    
    export PROC_PACKAGE_NAME=$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET.zip
    export PROC_PACKAGE_PATH=$PROC_PACKAGE_FOLDER/$PROC_PACKAGE_NAME

    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-functions/create-processing-function.sh
        source ../components/azure-functions/configure-processing-function-cosmosdb.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        source ../simulator/run-event-generator.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z $RUN ]; then
        source ../components/azure-event-hubs/report-throughput.sh
    fi
echo

echo "***** Done"

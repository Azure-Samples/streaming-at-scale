#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

on_error() {
    set +e
    echo "There was an error, execution halted" >&2
    echo "Error at line $1"
    exit 1
}

trap 'on_error $LINENO' ERR

export PREFIX=''
export LOCATION="eastus"
export TESTTYPE="1"
export SQL_TABLE_KIND="rowstore"
export STEPS="CIDPTM"

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-k <store-kind>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      D=DATABASE"
    echo "      P=PROCESSING"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "      V=VERIFY deployment"
    echo "-t: test 1,5,10 thousands msgs/sec. Default=$TESTTYPE"
    echo "-k: test rowstore, columnstore, rowstore-inmemory, columnstore-inmemory. Default=$SQL_TABLE_KIND"
    echo "-l: where to create the resources. Default=$LOCATION"
    exit 1; 
}

# Initialize parameters specified from command line
while getopts ":d:s:t:l:k:" arg; do
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
                k)
			SQL_TABLE_KIND=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$PREFIX" ]]; then
	echo "Enter a name for this deployment."
	usage
fi

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export EVENTHUB_PARTITIONS=16
    export EVENTHUB_CAPACITY=12
    export PROC_FUNCTION=Test0
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=16
    export SQL_SKU=P6
    export SIMULATOR_INSTANCES=5
fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=8
    export EVENTHUB_CAPACITY=6
    export PROC_FUNCTION=Test0
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=8
    export SQL_SKU=P4
    export SIMULATOR_INSTANCES=3
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_FUNCTION=Test0
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=2
    export SQL_SKU=P1
    export SIMULATOR_INSTANCES=1
fi

# last checks and variables setup
if [ -z ${SIMULATOR_INSTANCES+x} ]; then
    usage
fi

export RESOURCE_GROUP=$PREFIX

# remove log.txt if exists
rm -f log.txt

echo "Checking pre-requisites..."

source ../assert/has-local-az.sh
source ../assert/has-local-jq.sh
source ../assert/has-local-zip.sh
source ../assert/has-local-dotnet.sh

declare TABLE_SUFFIX=""
case $SQL_TABLE_KIND in
    rowstore)
        TABLE_SUFFIX=""
        ;;
    rowstore-inmemory)
        TABLE_SUFFIX="_mo"
        ;;
    columnstore)
        TABLE_SUFFIX="_cs"
        ;;
    columnstore-inmemory)
        TABLE_SUFFIX="_cs_mo"
        ;;
    *)
        echo "SQL_TABLE_KIND must be set to 'rowstore', 'rowstore-inmemory', 'columnstore' or 'columnstore-inmemory'"
        echo "please install it as it is needed by the script"
        exit 1
        ;;
esac

echo
echo "Streaming at Scale with Azure Functions and Azure SQL"
echo "====================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". Function        => Name: $PROC_FUNCTION, SKU: $PROC_FUNCTION_SKU, Workers: $PROC_FUNCTION_WORKERS"
echo ". Azure SQL       => SKU: $SQL_SKU, STORAGE_TYPE: $SQL_TABLE_KIND"
echo ". Simulators      => $SIMULATOR_INSTANCES"
echo

echo "Deployment started..."
echo

echo "***** [C] Setting up COMMON resources"

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
    export EVENTHUB_CG="azuresql"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/create-event-hub.sh
    fi
echo

echo "***** [D] Setting up DATABASE"

    export SQL_TYPE="db"
    export SQL_SERVER_NAME=$PREFIX"sql" 
    export SQL_DATABASE_NAME="streaming"    
    export SQL_ADMIN_PASS="Strong_Passw0rd!"  

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-sql/create-sql.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export PROC_FUNCTION_APP_NAME=$PREFIX"process"
    export PROC_FUNCTION_NAME=StreamingProcessor
    export PROC_PACKAGE_FOLDER=.
    export PROC_PACKAGE_TARGET=AzureSQL    
    export PROC_PACKAGE_NAME=$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET.zip
    export PROC_PACKAGE_PATH=$PROC_PACKAGE_FOLDER/$PROC_PACKAGE_NAME
    export SQL_PROCEDURE_NAME="stp_WriteData$TABLE_SUFFIX"

    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-functions/create-processing-function.sh
        source ../components/azure-functions/configure-processing-function-azuresql.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    export SIMULATOR_DUPLICATE_EVERY_N_EVENTS=-1

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        source ../simulator/run-generator-eventhubs.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/report-throughput.sh
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"

    export ADB_WORKSPACE=$PREFIX"databricks" 
    export ADB_TOKEN_KEYVAULT=$PREFIX"kv" #NB AKV names are limited to 24 characters
    export SQL_TABLE_NAME="[dbo].[rawdata$TABLE_SUFFIX]"

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-azuresql.sh
    fi
echo

echo "***** Done"

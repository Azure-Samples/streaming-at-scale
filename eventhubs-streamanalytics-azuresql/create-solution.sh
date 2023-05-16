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
export AZURE_SQL_TIER="HS"

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
    echo "-k: test rowstore or columnstore. Default=$SQL_TABLE_KIND"
    echo "-o: test Hyperscale (HS) or Business Critical (BC). Default=$AZURE_SQL_TIER"
    echo "-l: where to create the resources. Default=$LOCATION"
    exit 1; 
}

# Initialize parameters specified from command line
while getopts ":d:s:t:l:k:o:" arg; do
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
        o)
            AZURE_SQL_TIER=${OPTARG}
            ;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$PREFIX" ]]; then
    printf "\nError: Enter a name for this deployment.\n\n"   
	usage
fi

case $AZURE_SQL_TIER in
    HS|BC)
        ;;
    *)
        printf "\nError: '-o' param must be set to 'HS' or 'BC'\n\n"   
        usage
        ;;
esac

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export EVENTHUB_PARTITIONS=12
    export EVENTHUB_CAPACITY=12
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=18 # must be 1, 3, 6 or a multiple or 6
    export SQL_SKU=${AZURE_SQL_TIER}_Gen5_16
    export SIMULATOR_INSTANCES=5
fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=6
    export EVENTHUB_CAPACITY=6
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=12 # must be 1, 3, 6 or a multiple or 6
    export SQL_SKU=${AZURE_SQL_TIER}_Gen5_8
    export SIMULATOR_INSTANCES=3
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=6 # must be 1, 3, 6 or a multiple or 6
    export SQL_SKU=${AZURE_SQL_TIER}_Gen5_2
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

declare TABLE_SUFFIX=""
case $SQL_TABLE_KIND in
    rowstore)
        TABLE_SUFFIX=""
        ;;
    columnstore)
        TABLE_SUFFIX="_cs"
        ;;
    *)
        echo "'-k' param must be set to 'rowstore' or 'columnstore'"        
        usage
        ;;
esac

echo
echo "Streaming at Scale with Stream Analytics and AzureSQL"
echo "====================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration:"
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". StreamAnalytics => Name: $PROC_JOB_NAME, SU: $PROC_STREAMING_UNITS"
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

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    export SQL_TABLE_NAME="rawdata$TABLE_SUFFIX"

    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ./create-stream-analytics.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    export SIMULATOR_DUPLICATE_EVERY_N_EVENTS=0

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

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-azuresql.sh
    fi
echo

echo "***** Done"

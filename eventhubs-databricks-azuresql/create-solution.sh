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
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-k <store-kind>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=CIDPTM"
    echo "    Possibile values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      D=DATABASE"
    echo "      P=PROCESSING"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "-t: test 1,5,10 thousands msgs/sec. Default=1"
    echo "-k: test rowstore, columnstore. Default=rowstore"
    echo "-l: where to create the resources. Default=eastus"
    exit 1; 
}

export PREFIX=''
export LOCATION=''
export TESTTYPE=''
export STEPS=''
export SQL_TABLE_KIND=''

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

if [[ -z "$LOCATION" ]]; then
	export LOCATION="eastus"
fi

if [[ -z "$TESTTYPE" ]]; then
	export TESTTYPE="1"
fi

if [[ -z "$SQL_TABLE_KIND" ]]; then
	export SQL_TABLE_KIND="rowstore"
fi

if [[ -z "$STEPS" ]]; then
	export STEPS="CIDPTM"
fi

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export EVENTHUB_PARTITIONS=16
    export EVENTHUB_CAPACITY=12
    export SQL_SKU=P6
    export TEST_CLIENTS=30
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=16
    export DATABRICKS_MAXEVENTSPERTRIGGER=70000
fi

# 5500 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=10
    export EVENTHUB_CAPACITY=6
    export SQL_SKU=P4
    export TEST_CLIENTS=16 
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=10
    export DATABRICKS_MAXEVENTSPERTRIGGER=35000
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=4
    export EVENTHUB_CAPACITY=2
    export SQL_SKU=P2
    export TEST_CLIENTS=3 
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=4
    export DATABRICKS_MAXEVENTSPERTRIGGER=10000
fi

# last checks and variables setup
if [ -z ${TEST_CLIENTS+x} ]; then
    usage
fi

export RESOURCE_GROUP=$PREFIX

# remove log.txt if exists
rm -f log.txt

echo "Checking pre-requisites..."

HAS_AZ=$(command -v az || true)
if [ -z "$HAS_AZ" ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

HAS_JQ=$(command -v jq || true)
if [ -z "$HAS_JQ" ]; then
    echo "jq not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install jq"
    echo "or as described here:"
    echo "https://stedolan.github.io/jq/download/"
    exit 1
fi

HAS_PYTHON=$(command -v python || true)
if [ -z "$HAS_PYTHON" ]; then
    echo "python 2.7 not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install python"
    echo "or as described here:"
    echo "https://wiki.python.org/moin/BeginnersGuide/Download"
    exit 1
fi

HAS_DATABRICKSCLI=$(command -v databricks || true)
if [ -z "$HAS_DATABRICKSCLI" ]; then
    echo "databricks-cli not found"
    echo "please install it as described here:"
    echo "https://github.com/databricks/databricks-cli"
    exit 1
fi

AZ_SUBSCRIPTION_NAME=$(az account show --query name -o tsv || true)
if [ -z "$AZ_SUBSCRIPTION_NAME" ]; then
    #az account show already shows error message "Please run 'az login' to setup account."
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
        echo "SQL_TABLE_KIND must be set to 'rowstore', 'columnstore'"
        exit 1
        ;;
esac

echo
echo "Streaming at Scale with Databricks and Azure SQL"
echo "================================================"
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". Databricks      => VM: $DATABRICKS_NODETYPE, Workers: $DATABRICKS_WORKERS, maxEventsPerTrigger: $DATABRICKS_MAXEVENTSPERTRIGGER"
echo ". Azure SQL       => SKU: $SQL_SKU, STORAGE_TYPE: $SQL_TABLE_KIND"
echo ". Locusts         => $TEST_CLIENTS"
echo

echo "Deployment started..."
echo

echo "***** [C] Setting up COMMON resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z $RUN ]; then
        source ../components/azure-common/create-resource-group.sh
        source ../components/azure-storage/create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"    
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="azuresql"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z $RUN ]; then
        source ../components/azure-event-hubs/create-event-hub.sh
    fi
echo

echo "***** [D] Setting up DATABASE"

    export SQL_SERVER_NAME=$PREFIX"sql"
    export SQL_DATABASE_NAME="streaming"  
    export SQL_ADMIN_PASS="Strong_Passw0rd!"  
    export SQL_TABLE_NAME="rawdata$TABLE_SUFFIX"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z $RUN ]; then
        source ../components/azure-sql-database/create-sql-database.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export ADB_WORKSPACE=$PREFIX"databricks" 
    export ADB_TOKEN_KEYVAULT=$PREFIX"kv" #NB AKV names are limited to 24 characters
    export SQL_ETL_STORED_PROC="stp_WriteDataBatch$TABLE_SUFFIX"
    
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z $RUN ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/eventhubs-to-azuresql.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z $RUN ]; then
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

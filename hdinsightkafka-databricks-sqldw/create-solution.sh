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
export SQL_TABLE_KIND="columnstore"
export STEPS="CIDPTMV"

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
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
    echo "-k: test rowstore, columnstore. Default=columnstore"
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
    export HDINSIGHT_WORKERS="4"  
    export HDINSIGHT_WORKER_SIZE="Standard_D3_V2"  
    export KAFKA_PARTITIONS=16
    export SQL_SKU=DW100c
    export SIMULATOR_INSTANCES=5
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=16
    export DATABRICKS_MAXEVENTSPERTRIGGER=70000
fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export HDINSIGHT_WORKERS="4"  
    export HDINSIGHT_WORKER_SIZE="Standard_D3_V2"  
    export KAFKA_PARTITIONS=10
    export SQL_SKU=DW100c
    export SIMULATOR_INSTANCES=3 
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=10
    export DATABRICKS_MAXEVENTSPERTRIGGER=35000
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export HDINSIGHT_WORKERS="4"  
    export HDINSIGHT_WORKER_SIZE="Standard_D3_V2"  
    export KAFKA_PARTITIONS=4
    export SQL_SKU=DW100c
    export SIMULATOR_INSTANCES=1 
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=4
    export DATABRICKS_MAXEVENTSPERTRIGGER=10000
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
source ../assert/has-local-databrickscli.sh

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
echo "Streaming at Scale with Databricks and Azure SQL DW"
echo "==================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". HDInsight Kafka => VM: $HDINSIGHT_WORKER_SIZE, Workers: $HDINSIGHT_WORKERS, Partitions: $KAFKA_PARTITIONS"
echo ". Databricks      => VM: $DATABRICKS_NODETYPE, Workers: $DATABRICKS_WORKERS, maxEventsPerTrigger: $DATABRICKS_MAXEVENTSPERTRIGGER"
echo ". Azure SQL DW    => SKU: $SQL_SKU, STORAGE_TYPE: $SQL_TABLE_KIND"
echo ". Simulators      => $SIMULATOR_INSTANCES"
echo

echo "Deployment started..."
echo

echo "***** [C] Setting up COMMON resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"
    export VNET_NAME=$PREFIX"-vnet"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-common/create-resource-group.sh
        source ../components/azure-common/create-virtual-network.sh
        source ../components/azure-storage/create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION"
    
    export LOG_ANALYTICS_WORKSPACE=$PREFIX"mon"    
    export HDINSIGHT_NAME=$PREFIX"hdi"    
    export HDINSIGHT_PASSWORD="Strong_Passw0rd!"  

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-monitor/create-log-analytics.sh
        source ../components/azure-hdinsight/create-hdinsight-kafka.sh
    fi
echo

echo "***** [D] Setting up DATABASE"

    export SQL_TYPE="dw"
    export SQL_SERVER_NAME=$PREFIX"sql"
    export SQL_DATABASE_NAME="streaming"  
    export SQL_ADMIN_PASS="Strong_Passw0rd!"  
    export SQL_TABLE_NAME="rawdata$TABLE_SUFFIX"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-sql/create-sql.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export ADB_WORKSPACE=$PREFIX"databricks" 
    export ADB_TOKEN_KEYVAULT=$PREFIX"kv" #NB AKV names are limited to 24 characters
    export KAFKA_TOPIC="streaming"
    export SQL_ETL_STORED_PROC="stp_WriteDataBatch$TABLE_SUFFIX"
    
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../components/azure-databricks/peer-databricks-vnet.sh
        source ../components/azure-hdinsight/get-hdinsight-kafka-brokers.sh
        source ../streaming/databricks/runners/kafka-to-sqldw.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-hdinsight/get-hdinsight-kafka-brokers.sh
        source ../simulator/run-generator-kafka.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-hdinsight/get-hdinsight-kafka-brokers.sh
        source ../components/azure-hdinsight/report-throughput.sh
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-sqldw.sh
    fi
echo

echo "***** Done"

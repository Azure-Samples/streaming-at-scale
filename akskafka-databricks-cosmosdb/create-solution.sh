#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

export PREFIX=''
export LOCATION="eastus"
export TESTTYPE="1"
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
    echo "-l: where to create the resources. Default=$LOCATION"
    exit 1; 
}

# Initialize parameters specified from command line
while getopts ":d:s:t:l:" arg; do
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
		esac
done
shift $((OPTIND-1))

if [[ -z "$PREFIX" ]]; then
	echo "Enter a name for this deployment."
	usage
fi

export AKS_VM_SIZE=Standard_D4s_v3
export AKS_KUBERNETES_VERSION=1.14.7

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export AKS_NODES=9
    export KAFKA_BROKERS=16
    export KAFKA_PARTITIONS=16
    export COSMOSDB_RU=100000
    export SIMULATOR_INSTANCES=5
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=16
    export DATABRICKS_MAXEVENTSPERTRIGGER=100000
fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export AKS_NODES=6
    export KAFKA_BROKERS=10
    export KAFKA_PARTITIONS=10
    export COSMOSDB_RU=50000
    export SIMULATOR_INSTANCES=3
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=10
    export DATABRICKS_MAXEVENTSPERTRIGGER=50000
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export AKS_NODES=3
    export KAFKA_BROKERS=4
    export KAFKA_PARTITIONS=4
    export COSMOSDB_RU=20000
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

source ../assert/has-local-kubectl.sh
source ../assert/has-local-az.sh
source ../assert/has-local-jq.sh
source ../assert/has-local-databrickscli.sh
source ../assert/has-local-helm.sh

echo
echo "Streaming at Scale with Azure Databricks and CosmosDB"
echo "====================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". AKS Kafka       => Node Count: $AKS_NODES, VM: $AKS_VM_SIZE"
echo ". Databricks      => VM: $DATABRICKS_NODETYPE, Workers: $DATABRICKS_WORKERS, maxEventsPerTrigger: $DATABRICKS_MAXEVENTSPERTRIGGER"
echo ". CosmosDB        => RU: $COSMOSDB_RU"
echo ". Simulators      => $SIMULATOR_INSTANCES"
echo

echo "Deployment started..."
echo

echo "***** [C] Setting up COMMON resources"

    export AKS_CLUSTER=$PREFIX"aks" 
    export SERVICE_PRINCIPAL_KV_NAME=$AKS_CLUSTER
    export SERVICE_PRINCIPAL_KEYVAULT=$PREFIX"spkv"
    export ACR_NAME=$PREFIX"acr"
    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"
    export VNET_NAME=$PREFIX"-vnet"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-common/create-resource-group.sh
        source ../components/azure-common/create-service-principal.sh
        source ../components/azure-common/create-virtual-network.sh
        source ../components/azure-storage/create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION"
    
    source ../components/azure-monitor/generate-workspace-name.sh

    export KAFKA_TOPIC=$PREFIX"topic"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-monitor/create-log-analytics.sh
        source ../components/azure-kubernetes-service/create-kubernetes-service.sh
        source ../components/azure-kubernetes-service/deploy-aks-kafka.sh
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

    export ADB_WORKSPACE=$PREFIX"databricks" 
    export ADB_TOKEN_KEYVAULT=$PREFIX"kv" #NB AKV names are limited to 24 characters
    export KAFKA_TOPIC=$PREFIX"topic"    

    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-kubernetes-service/get-aks-kafka-brokers.sh 
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/kafka-to-cosmosdb.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-kubernetes-service/get-aks-kafka-brokers.sh
        source ../simulator/run-generator-kafka.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-kubernetes-service/aks-kafka-report-throughput.sh
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-cosmosdb.sh
    fi
echo

echo "***** Done"

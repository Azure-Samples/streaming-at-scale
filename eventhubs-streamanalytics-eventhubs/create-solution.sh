#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

export PREFIX=''
export LOCATION="eastus"
export TESTTYPE="1"
export STEPS="CIPTM"
export STREAM_ANALYTICS_JOBTYPE='simple'

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      P=PROCESSING"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "      V=VERIFY deployment"
    echo "-t: test 1,5,10 thousands msgs/sec. Default=$TESTTYPE"
    echo "-a: type of job: simple or anomalydetection. Default=simple"
    echo "-l: where to create the resources. Default=$LOCATION"
    exit 1; 
}

# Initialize parameters specified from command line
while getopts ":d:s:t:l:a:" arg; do
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
		a)
			STREAM_ANALYTICS_JOBTYPE=${OPTARG}
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
    export EVENTHUB_PARTITIONS=12
    export EVENTHUB_CAPACITY=12
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=24 # must be 1, 3, 6 or a multiple or 6
    export SIMULATOR_INSTANCES=5
fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=8
    export EVENTHUB_CAPACITY=6
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=12 # must be 1, 3, 6 or a multiple or 6
    export SIMULATOR_INSTANCES=3
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=3 # must be 1, 3, 6 or a multiple or 6
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

echo
echo "Streaming at Scale with Stream Analytics and Event Hubs"
echo "======================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". StreamAnalytics => Name: $PROC_JOB_NAME, SU: $PROC_STREAMING_UNITS, Job type: $STREAM_ANALYTICS_JOBTYPE"
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

echo "***** [I] Setting up INGESTION AND EGRESS EVENT HUBS"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"
    export EVENTHUB_NAMESPACE_OUT=$PREFIX"eventhubsout"
    export EVENTHUB_NAMESPACES="$EVENTHUB_NAMESPACE $EVENTHUB_NAMESPACE_OUT"
    export EVENTHUB_NAME="streamingatscale-$EVENTHUB_PARTITIONS"
    export EVENTHUB_CG="asa"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-event-hubs/create-event-hub.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        source ./create-stream-analytics.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

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
    export ALLOW_DUPLICATES=1

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-eventhubs.sh
    fi
echo

echo "***** Done"

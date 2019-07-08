#!/bin/bash

set -euo pipefail

export PREFIX=''
export LOCATION='eastus'
export TESTTYPE='1'
export STEPS='CIPTM'
export STREAM_ANALYTICS_JOBTYPE='simple'

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possibile values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      P=PROCESSING"
    echo "      T=TEST clients" 
    echo "      M=METRICS reporting"
    echo "-t: test 1,5,10 thousands msgs/sec. Default=1"
    echo "-a: type of job: simple or anomalydetection. Default=simple"
    echo "-l: where to create the resources. Default=eastus"
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
    export EVENTHUB_CAPACITY=10
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=24 # must be 1, 3, 6 or a multiple or 6
    export TEST_CLIENTS=30
fi

# 5500 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=6
    export EVENTHUB_CAPACITY=6
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=12 # must be 1, 3, 6 or a multiple or 6
    export TEST_CLIENTS=16
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=3 # must be 1, 3, 6 or a multiple or 6
    export TEST_CLIENTS=3
fi

# last checks and variables setup
if [ -z ${TEST_CLIENTS+x} ]; then
    usage
fi

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
    echo "please install it using your package manager, for example, on Uuntu:"
    echo "  sudo apt install jq"
    echo "or as described here:"
    echo "  https://stedolan.github.io/jq/download/"
    exit 1
fi

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
echo ". Locusts         => $TEST_CLIENTS"
echo

echo "***** [C] Setting up common resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z $RUN ]; then
        source ../components/resource-group/create-resource-group.sh
        source ../components/azure-storage/create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION AND EGRESS EVENT HUBS"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_NAME_OUT=$PREFIX"out-"$EVENTHUB_PARTITIONS
    export EVENTHUB_NAMES="$EVENTHUB_NAME $EVENTHUB_NAME_OUT"
    export EVENTHUB_CG="asa"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z $RUN ]; then
        source ../components/event-hubs/create-event-hub.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z $RUN ]; then
        source ./create-stream-analytics.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z $RUN ]; then
        source ../simulator/run-event-generator.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z $RUN ]; then
        source ../components/event-hubs/report-throughput.sh
    fi
echo

echo "***** done"

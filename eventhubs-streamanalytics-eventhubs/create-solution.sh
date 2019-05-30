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
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]" 1>&2; 
    echo "-s: specify which steps should be executed. Default=CIDPT" 1>&2; 
    echo "    Possibile values:" 1>&2; 
    echo "      C=COMMON" 1>&2; 
    echo "      I=INGESTION" 1>&2; 
    echo "      P=PROCESSING" 1>&2; 
    echo "      T=TEST clients" 1>&2; 
    echo "-t: test 1,5,10 thousands msgs/sec. Default=1"
    echo "-l: where to create the resources. Default=eastus"
    exit 1; 
}

export PREFIX=''
export LOCATION=''
export TESTTYPE=''
export STEPS=''

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

if [[ -z "$LOCATION" ]]; then
	export LOCATION="eastus"
fi

if [[ -z "$TESTTYPE" ]]; then
	export TESTTYPE="1"
fi

if [[ -z "$STEPS" ]]; then
	export STEPS="CIPT"
fi

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export EVENTHUB_PARTITIONS=12
    export EVENTHUB_CAPACITY=10
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=12 # must be 1, 3, 6 or a multiple or 6
    export TEST_CLIENTS=30
fi

# 5500 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export EVENTHUB_PARTITIONS=6
    export EVENTHUB_CAPACITY=6
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=6 # must be 1, 3, 6 or a multiple or 6
    export TEST_CLIENTS=16
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=1 # must be 1, 3, 6 or a multiple or 6
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
echo ". StreamAnalytics => Name: $PROC_JOB_NAME, SU: $PROC_STREAMING_UNITS"
echo ". Locusts         => $TEST_CLIENTS"
echo

echo "***** [C] Setting up common resources"

    export AZURE_STORAGE_ACCOUNT=$PREFIX"storage"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z $RUN ]; then
        ../_common/01-create-resource-group.sh
        ../_common/02-create-storage-account.sh
    fi
echo 

echo "***** [I] Setting up INGESTION AND EGRESS EVENT HUBS"
    
    export EVENTHUB_NAMESPACE=$PREFIX"eventhubs"
    export EVENTHUB_NAME=$PREFIX"in-"$EVENTHUB_PARTITIONS
    export EVENTHUB_NAME_OUT=$PREFIX"out-"$EVENTHUB_PARTITIONS
    export EVENTHUB_CG="asa"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z $RUN ]; then
        ./01-create-event-hub.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"

    export PROC_JOB_NAME=$PREFIX"streamingjob"
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z $RUN ]; then
        ./02-create-stream-analytics.sh
    fi
echo

echo "***** [T] Starting up TEST clients"

    export LOCUST_DNS_NAME=$PREFIX"locust"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z $RUN ]; then
        ./03-run-clients.sh
    fi
echo

echo "***** done"

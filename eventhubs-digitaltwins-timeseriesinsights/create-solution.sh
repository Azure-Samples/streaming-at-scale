#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

export PREFIX=''
export LOCATION="eastus"
export STEPS="DM"

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      D=DEPLOYMENT"
    echo "      M=METRICS reporting"
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

export RESOURCE_GROUP=$PREFIX

# remove log.txt if exists
rm -f log.txt

echo "Checking pre-requisites..."

source ../assert/has-local-az.sh
source ../assert/has-local-jq.sh
source ../assert/has-local-terraform.sh

echo
echo "Streaming at Scale with Azure Time Series Insights"
echo "=================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo

echo "Deployment started..."
echo

echo "***** [D] Performing DEPLOYMENT"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        terraform init
        terraform plan -var appname=$RESOURCE_GROUP -var resource_group=$RESOURCE_GROUP -var location=$LOCATION -out tfplan
        terraform apply tfplan
    fi
echo

echo "To run Explorer:"
echo "    open $(terraform output -raw digital_twins_explorer_url)"
echo "    Enter URL $(terraform output -raw digital_twins_service_url)"
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        export EVENTHUB_NAMESPACES=$(terraform output -raw eventhub_namespace_names)
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
        source ../streaming/databricks/runners/verify-timeseriesinsights.sh
    fi
echo

echo "***** Done"


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
export STEPS="CIPM"

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      C=COMMON"
    echo "      I=INGESTION"
    echo "      P=PROCESSING"
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
source ../assert/has-local-func.sh

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

echo "***** [C] Setting up COMMON resources"

    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z "$RUN" ]; then
        terraform init
        terraform plan -var appname=$RESOURCE_GROUP -var resource_group=$RESOURCE_GROUP -var location=$LOCATION -out tfplan
        terraform apply tfplan
    fi
echo

echo "***** [I] Setting up INGESTION"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        function_name_event_hub_to_digital_twins=$(terraform output -raw function_name_event_hub_to_digital_twins)
        function_name_digital_twins_to_time_series_insights=$(terraform output -raw function_name_digital_twins_to_time_series_insights)

        (cd functions/EventHubToDigitalTwins; func azure functionapp publish $function_name_event_hub_to_digital_twins)
        (cd functions/DigitalTwinsToTSI; func azure functionapp publish $function_name_digital_twins_to_time_series_insights)
    fi
echo

echo "***** [P] Setting up PROCESSING"

    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then
        digital_twins_service_url=$(terraform output -raw digital_twins_service_url)
        digital_twins_explorer_url=$(terraform output -raw digital_twins_explorer_url || true)
        time_series_insights_data_access_fqdn=$(terraform output -raw time_series_insights_data_access_fqdn)
        
        dotnet run -p functions/ModelGenerator "$digital_twins_service_url" "$time_series_insights_data_access_fqdn" "models/digital_twin_types.json" "models/time_series_insights_types.json" "models/time_series_insights_hierarchies.json"

        echo "To run Explorer:"
        echo "    open $digital_twins_explorer_url"
        echo "    Enter URL $digital_twins_service_url"
        echo
    fi
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

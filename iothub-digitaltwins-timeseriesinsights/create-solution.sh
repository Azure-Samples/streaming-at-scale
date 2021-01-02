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
export STEPS="IDTM"

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      I=INFRASTRUCTURE"
    echo "      D=DATA"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "-t: test 1,2 thousands msgs/sec. Default=$TESTTYPE"
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


# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export TF_VAR_iothub_sku="S2"
    export TF_VAR_iothub_capacity=10
    export TF_VAR_simulator_events_per_second=1000
    export TF_VAR_function_sku=EP2
    export TF_VAR_function_workers=2
    export SIMULATOR_INSTANCES=1
fi

# 2000 messages/sec
if [ "$TESTTYPE" == "2" ]; then
    export TF_VAR_iothub_sku="S2"
    export TF_VAR_iothub_capacity=20
    export TF_VAR_simulator_events_per_second=2000
    export TF_VAR_function_sku=EP2
    export TF_VAR_function_workers=4
    export SIMULATOR_INSTANCES=1
fi

# last checks and variables setup
if [ -z ${TF_VAR_iothub_sku+x} ]; then
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
source ../assert/has-local-terraform.sh

echo
echo "Streaming at Scale with Azure Digital Twins"
echo "==========================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". IoT Hub         => SKU: $TF_VAR_iothub_sku, Capacity: $TF_VAR_iothub_capacity"
echo ". Function        => SKU: $TF_VAR_function_sku, Workers: $TF_VAR_function_workers"
echo ". Simulators      => $SIMULATOR_INSTANCES"
echo

echo "Deployment started..."
echo

echo "***** [I] Deploying INFRASTRUCTURE"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        terraform init
        terraform plan -var appname=$RESOURCE_GROUP -var resource_group=$RESOURCE_GROUP -var location=$LOCATION -out tfplan
        terraform apply tfplan
    fi
echo

echo "***** [D] Setting up DATA"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        iothub_registry_write_primary_connection_string=$(terraform output -raw iothub_registry_write_primary_connection_string)
        digital_twins_service_url=$(terraform output -raw digital_twins_service_url)
        digital_twins_explorer_url=$(terraform output -raw digital_twins_explorer_url || true)
        time_series_insights_data_access_fqdn=$(terraform output -raw time_series_insights_data_access_fqdn)

        CONNECTION_STRING="$iothub_registry_write_primary_connection_string" dotnet run -p src/PopulateIoTHub
        dotnet run -p src/PopulateDigitalTwinsModel "$digital_twins_service_url" "models/digital_twin_types.json"
        dotnet run -p src/PopulateTimeSeriesInsightsModel "$time_series_insights_data_access_fqdn" "models/time_series_insights_types.json" "models/time_series_insights_hierarchies.json"

        echo "To run Explorer:"
        echo "    open $digital_twins_explorer_url"
        echo "    Enter URL $digital_twins_service_url"
        echo
    fi
echo

echo "***** [T] Starting up TEST clients"

    export SIMULATOR_DUPLICATE_EVERY_N_EVENTS=-1

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        source run-simulator.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        export IOTHUB_RESOURCES=$(terraform output -raw iothub_resource_id)
        export EVENTHUB_NAMESPACES=$(terraform output -raw eventhub_namespace_names)
        source ../components/azure-event-hubs/report-throughput.sh
    fi
echo

echo "***** Done"

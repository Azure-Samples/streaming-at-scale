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
export TESTTYPE="50"
export STEPS="IDTM"

usage() { 
    echo "Usage: $0 -d <deployment-name> [-s <steps>] [-t <test-type>] [-l <location>]"
    echo "-s: specify which steps should be executed. Default=$STEPS"
    echo "    Possible values:"
    echo "      I=INFRASTRUCTURE"
    echo "      D=DATA"
    echo "      T=TEST clients"
    echo "      M=METRICS reporting"
    echo "      V=VERIFY deployment"
    echo "-t: test 50,100 msgs/sec. Default=$TESTTYPE"
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


# 50 messages/sec
if [ "$TESTTYPE" == "50" ]; then
    export TF_VAR_iothub_sku="S1"
    export TF_VAR_iothub_capacity=1
    export TF_VAR_function_sku=EP2
    export TF_VAR_function_workers=1
    export EVENTS_PER_SECOND=50
    export SIMULATOR_INSTANCES=1
fi

# 100 messages/sec
if [ "$TESTTYPE" == "100" ]; then
    export TF_VAR_iothub_sku="S2"
    export TF_VAR_iothub_capacity=3
    export TF_VAR_function_sku=EP2
    export TF_VAR_function_workers=1
    export EVENTS_PER_SECOND=100
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
source ../assert/has-local-dotnet.sh
source ../assert/has-local-terraform.sh

echo
echo "Streaming at Scale with Azure Digital Twins and Azure Time Series Insights"
echo "=========================================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". IoT Hub         => SKU: $TF_VAR_iothub_sku, Capacity: $TF_VAR_iothub_capacity"
echo ". Function        => SKU: $TF_VAR_function_sku, Workers: $TF_VAR_function_workers"
echo ". TS Insights     => PAYG"
echo ". Simulators      => $SIMULATOR_INSTANCES"
echo

echo "Deployment started..."
echo

TERRAFORM="terraform"

echo "***** [I] Deploying INFRASTRUCTURE"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        $TERRAFORM init
        $TERRAFORM plan -var appname=$RESOURCE_GROUP -var resource_group=$RESOURCE_GROUP -var location=$LOCATION -out tfplan
        $TERRAFORM apply tfplan
    fi
echo

echo "***** [D] Setting up DATA"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        IOTHUB_NAME=$($TERRAFORM output -raw iothub_name)
        digital_twins_service_url=$($TERRAFORM output -raw digital_twins_service_url)
        time_series_insights_data_access_fqdn=$($TERRAFORM output -raw time_series_insights_data_access_fqdn)

        source ../components/azure-iot-hub/provision-iot-hub-devices.sh
        dotnet run -p src/PopulateDigitalTwinsModel "$digital_twins_service_url" "models/digital_twin_types.json"
        dotnet run -p src/PopulateTimeSeriesInsightsModel "$time_series_insights_data_access_fqdn" "models/time_series_insights_types.json" "models/time_series_insights_hierarchies.json"
    fi
echo

echo "***** [T] Starting up TEST clients"

    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then
        export SIMULATOR_CONNECTION_SETTING=IotHubConnectionString="$($TERRAFORM output -raw iothub_telemetry_send_primary_connection_string)"
        source ../simulator/run-simulator.sh
    fi
echo

echo "***** [M] Starting METRICS reporting"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
        export IOTHUB_RESOURCES=$($TERRAFORM output -raw iothub_resource_id)
        export EVENTHUB_NAMESPACES=$($TERRAFORM output -raw eventhub_namespace_names)
        source ../components/azure-event-hubs/report-throughput.sh
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"

    export ADB_WORKSPACE="dbw-$PREFIX" 
    export ADB_TOKEN_KEYVAULT="kvd$PREFIX" #NB AKV names are limited to 24 characters
    export ALLOW_DUPLICATES=1
    export TSI_ENVIRONMENT=$($TERRAFORM output -raw time_series_insights_name)
    export AZURE_STORAGE_ACCOUNT=$($TERRAFORM output -raw time_series_insights_storage_account_name)

    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        source ../components/azure-databricks/create-databricks.sh
        source ../streaming/databricks/runners/verify-timeseriesinsights.sh
    fi
echo

echo "***** Done"

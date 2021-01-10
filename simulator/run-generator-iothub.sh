#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'getting IoT Hub connection string'
policy_name=device
registry_key=$(az iot hub policy show --hub-name $IOTHUB_NAME --name device --query primaryKey -o tsv)
iothub_cs="HostName=$IOTHUB_NAME.azure-devices.net;SharedAccessKeyName=$policy_name;SharedAccessKey=$registry_key"

SIMULATOR_VARIABLES=""
SIMULATOR_CONNECTION_SETTING="IoTHubConnectionString=$iothub_cs"

source ../simulator/run-simulator.sh

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

eventhub_endpoint=$(az iot hub show -g $RESOURCE_GROUP --name $IOTHUB_NAME --query properties.eventHubEndpoints.events.endpoint -o tsv)
eventhub_hub_name=$(az iot hub show -g $RESOURCE_GROUP --name $IOTHUB_NAME --query properties.eventHubEndpoints.events.path -o tsv)
policy_name="service"
access_key=$(az iot hub policy show --hub-name $IOTHUB_NAME --name $policy_name --query primaryKey -o tsv)
EVENTHUB_CS="Endpoint=$eventhub_endpoint;SharedAccessKeyName=$policy_name;SharedAccessKey=$access_key"
EVENTHUB_NAME=$eventhub_hub_name

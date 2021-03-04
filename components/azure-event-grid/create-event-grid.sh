#!/bin/bash
set -euo pipefail

# prepare the CLI to be able to create an event grid topic
az provider register --namespace Microsoft.EventGrid

echo 'creating event grid system topic'
echo "name: $EVENT_GRID_SYSTEM_TOPIC_NAME"

## Create the system topic on the storage acount
az eventgrid system-topic create \
    -g $RESOURCE_GROUP \
    --name $EVENT_GRID_SYSTEM_TOPIC_NAME \
    --location $LOCATION \
    --topic-type $EVENT_GRID_SYSTEM_TOPIC_TYPE \
    --source $STORAGEID
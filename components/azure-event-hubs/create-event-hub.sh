#!/bin/bash

set -euo pipefail

EVENTHUB_CAPTURE=${EVENTHUB_CAPTURE:-False}
EVENTHUB_NAMES=${EVENTHUB_NAMES:-$EVENTHUB_NAME}

echo 'creating eventhubs namespace'
echo ". name: $EVENTHUB_NAMESPACE"
echo ". capacity: $EVENTHUB_CAPACITY"
echo ". capture: $EVENTHUB_CAPTURE"
echo ". auto-inflate: false"

az eventhubs namespace create -n $EVENTHUB_NAMESPACE -g $RESOURCE_GROUP \
    --sku Standard --location $LOCATION --capacity $EVENTHUB_CAPACITY \
    --enable-auto-inflate false \
    -o tsv >> log.txt

for eventHubName in $EVENTHUB_NAMES; do

echo 'creating eventhub instance'
echo ". name: $eventHubName"
echo ". partitions: $EVENTHUB_PARTITIONS"

az eventhubs eventhub create -n $eventHubName -g $RESOURCE_GROUP \
    --message-retention 1 --partition-count $EVENTHUB_PARTITIONS --namespace-name $EVENTHUB_NAMESPACE \
    --enable-capture "$EVENTHUB_CAPTURE" --capture-interval 300 --capture-size-limit 314572800 \
    --archive-name-format '{Namespace}/{EventHub}/{Year}_{Month}_{Day}_{Hour}_{Minute}_{Second}_{PartitionId}' \
    --blob-container eventhubs \
    --destination-name 'EventHubArchive.AzureBlockBlob' \
    --storage-account $AZURE_STORAGE_ACCOUNT \
    -o tsv >> log.txt

if [ -n "${EVENTHUB_CG:-}" ]; then
echo 'creating consumer group'
echo ". name: $EVENTHUB_CG"

az eventhubs eventhub consumer-group create -n $EVENTHUB_CG -g $RESOURCE_GROUP \
    --eventhub-name $eventHubName --namespace-name $EVENTHUB_NAMESPACE \
    -o tsv >> log.txt
fi

az eventhubs eventhub authorization-rule create -g $RESOURCE_GROUP --eventhub-name $eventHubName \
    --namespace-name $EVENTHUB_NAMESPACE \
    --name Listen --rights Listen \
    -o tsv >> log.txt

az eventhubs eventhub authorization-rule create -g $RESOURCE_GROUP --eventhub-name $eventHubName \
    --namespace-name $EVENTHUB_NAMESPACE \
    --name Send --rights Send \
    -o tsv >> log.txt

done

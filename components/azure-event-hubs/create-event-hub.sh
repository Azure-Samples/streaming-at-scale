#!/bin/bash

set -euo pipefail

EVENTHUB_CAPTURE=${EVENTHUB_CAPTURE:-False}
EVENTHUB_NAMESPACES=${EVENTHUB_NAMESPACES:-$EVENTHUB_NAMESPACE}
EVENTHUB_NAMES=${EVENTHUB_NAMES:-$EVENTHUB_NAME}

for eventHubsNamespace in $EVENTHUB_NAMESPACES; do

echo 'creating eventhubs namespace'
echo ". name: $eventHubsNamespace"
echo ". capacity: $EVENTHUB_CAPACITY"
echo ". capture: $EVENTHUB_CAPTURE"
echo ". auto-inflate: false"

if ! az eventhubs namespace show -n $eventHubsNamespace -g $RESOURCE_GROUP -o none 2>/dev/null; then
  az eventhubs namespace create -n $eventHubsNamespace -g $RESOURCE_GROUP \
    --sku Standard --location $LOCATION --capacity $EVENTHUB_CAPACITY \
    --enable-kafka "${EVENTHUB_ENABLE_KAFKA:-false}" \
    --enable-auto-inflate false \
    -o tsv >> log.txt
fi

for eventHubName in $EVENTHUB_NAMES; do

echo 'creating eventhub instance'
echo ". name: $eventHubName"
echo ". partitions: $EVENTHUB_PARTITIONS"

az eventhubs eventhub create -n $eventHubName -g $RESOURCE_GROUP \
    --partition-count $EVENTHUB_PARTITIONS --namespace-name $eventHubsNamespace \
    --enable-capture "$EVENTHUB_CAPTURE" --capture-interval 300 --capture-size-limit 314572800 \
    --archive-name-format 'capture/{Namespace}/{EventHub}/{Year}_{Month}_{Day}_{Hour}_{Minute}_{Second}_{PartitionId}' \
    --blob-container streamingatscale \
    --destination-name 'EventHubArchive.AzureBlockBlob' \
    --storage-account ${AZURE_STORAGE_ACCOUNT_GEN2:-$AZURE_STORAGE_ACCOUNT} \
    -o tsv >> log.txt

az eventhubs namespace authorization-rule create -g $RESOURCE_GROUP \
    --namespace-name $eventHubsNamespace \
    --name Listen --rights Listen \
    -o tsv >> log.txt

az eventhubs namespace authorization-rule create -g $RESOURCE_GROUP \
    --namespace-name $eventHubsNamespace \
    --name Send --rights Send \
    -o tsv >> log.txt

if [ -n "${EVENTHUB_CG:-}" ]; then
    echo 'creating consumer group'
    echo ". name: $EVENTHUB_CG"

    az eventhubs eventhub consumer-group create -n $EVENTHUB_CG -g $RESOURCE_GROUP \
        --eventhub-name $eventHubName --namespace-name $eventHubsNamespace \
        -o tsv >> log.txt
    fi
done

done

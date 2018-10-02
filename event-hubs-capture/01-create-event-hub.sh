#!/bin/bash

echo 'creating eventhubs namespace'
echo ". name: $EVENTHUB_NAMESPACE"
echo ". capacity: $EVENTHUB_CAPACITY"

az eventhubs namespace create -n $EVENTHUB_NAMESPACE -g $RESOURCE_GROUP \
--sku Standard --location $LOCATION --capacity $EVENTHUB_CAPACITY \
-o tsv >> log.txt

echo 'creating eventhub instance'
echo ". name: $EVENTHUB_NAME"
echo ". partitions: $EVENTHUB_PARTITIONS"

az eventhubs eventhub create -n $EVENTHUB_NAME -g $RESOURCE_GROUP \
--message-retention 1 --partition-count $EVENTHUB_PARTITIONS --namespace-name $EVENTHUB_NAMESPACE \
--enable-capture true --capture-interval 300 --capture-size-limit 314572800 \
--archive-name-format '{Namespace}/{EventHub}/{Year}_{Month}_{Day}_{Hour}_{Minute}_{Second}_{PartitionId}' \
--blob-container eventhubs \
--destination-name 'EventHubArchive.AzureBlockBlob' \
--storage-account $AZURE_STORAGE_ACCOUNT \
-o tsv >> log.txt


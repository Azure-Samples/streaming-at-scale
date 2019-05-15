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
-o tsv >> log.txt

echo 'creating eventhub instance'
echo ". name: $EVENTHUB_NAME_OUT"
echo ". partitions: $EVENTHUB_PARTITIONS"


az eventhubs eventhub create -n $EVENTHUB_NAME_OUT -g $RESOURCE_GROUP \
--message-retention 1 --partition-count $EVENTHUB_PARTITIONS --namespace-name $EVENTHUB_NAMESPACE \
-o tsv >> log.txt

echo 'creating consumer group'
echo ". name: $EVENTHUB_CG"

az eventhubs eventhub consumer-group create -n $EVENTHUB_CG -g $RESOURCE_GROUP \
--eventhub-name $EVENTHUB_NAME --namespace-name $EVENTHUB_NAMESPACE \
-o tsv >> log.txt


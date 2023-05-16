#!/bin/bash

set -euo pipefail

IOTHUB_PROVISIONING_ACI=$PREFIX"prov"

echo 'creating IoT Hub'
echo ". name: $IOTHUB_NAME"
echo ". sku: $IOTHUB_SKU"
echo ". units: $IOTHUB_UNITS"
az iot hub create -n $IOTHUB_NAME -g $RESOURCE_GROUP \
  --sku $IOTHUB_SKU --location $LOCATION --unit $IOTHUB_UNITS \
  --partition-count $IOTHUB_PARTITIONS \
  -o tsv >> log.txt

if [ -n "${EVENTHUB_CG:-}" ]; then
    echo 'creating consumer group'
    echo ". name: $EVENTHUB_CG"

    az iot hub consumer-group create -n $EVENTHUB_CG -g $RESOURCE_GROUP \
        --hub-name $IOTHUB_NAME \
        -o tsv >> log.txt
fi

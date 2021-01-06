#!/bin/bash

set -euo pipefail

echo 'creating IoT Hub'
echo ". name: $IOTHUB_NAME"
echo ". sku: $IOTHUB_SKU"
echo ". units: $IOTHUB_UNITS"

#if ! az iot hub show -n $IOTHUB_NAME -g $RESOURCE_GROUP -o none 2>/dev/null; then
  az iot hub create -n $IOTHUB_NAME -g $RESOURCE_GROUP \
    --sku $IOTHUB_SKU --location $LOCATION --unit $IOTHUB_UNITS \
    --partition-count $IOTHUB_PARTITIONS \
    -o tsv >> log.txt
#fi

IOTHUB_PROVISIONING_ACI=$PREFIX"prov"
echo 'provisioning devices'
echo ". name: $IOTHUB_PROVISIONING_ACI"
policy_name=registryReadWrite
registry_key=$(az iot hub policy show --hub-name $IOTHUB_NAME --name registryReadWrite --query primaryKey -o tsv)
iothub_cs="HostName=$IOTHUB_NAME.azure-devices.net;SharedAccessKeyName=$policy_name;SharedAccessKey=$registry_key"

az container create \
  --name $IOTHUB_PROVISIONING_ACI \
  --resource-group $RESOURCE_GROUP \
  --image iottelemetrysimulator/azureiot-simulatordeviceprovisioning \
  --restart-policy Never \
  -e \
    IotHubConnectionString="$iothub_cs" \
    DevicePrefix=contoso-device-id- \
    DeviceIndex=0 \
    DeviceCount=1000

if [ -n "${EVENTHUB_CG:-}" ]; then
    echo 'creating consumer group'
    echo ". name: $EVENTHUB_CG"

    az iot hub consumer-group create -n $EVENTHUB_CG -g $RESOURCE_GROUP \
        --hub-name $IOTHUB_NAME \
        -o tsv >> log.txt
fi

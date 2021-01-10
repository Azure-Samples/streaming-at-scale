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

echo 'provisioning devices'
echo ". Azure Container Instance name: $IOTHUB_PROVISIONING_ACI"
policy_name=registryReadWrite
registry_key=$(az iot hub policy show --hub-name $IOTHUB_NAME --name registryReadWrite --query primaryKey -o tsv)
iothub_cs="HostName=$IOTHUB_NAME.azure-devices.net;SharedAccessKeyName=$policy_name;SharedAccessKey=$registry_key"

az container delete -g $RESOURCE_GROUP -n $IOTHUB_PROVISIONING_ACI --yes \
  -o tsv >> log.txt 2>/dev/null
az container create \
  --name $IOTHUB_PROVISIONING_ACI \
  --resource-group $RESOURCE_GROUP \
  --image iottelemetrysimulator/azureiot-simulatordeviceprovisioning \
  --restart-policy Never \
  -e \
    IotHubConnectionString="$iothub_cs" \
    DevicePrefix=contoso-device-id- \
    DeviceIndex=0 \
    DeviceCount=1000 \
    -o tsv >> log.txt

if [ -n "${EVENTHUB_CG:-}" ]; then
    echo 'creating consumer group'
    echo ". name: $EVENTHUB_CG"

    az iot hub consumer-group create -n $EVENTHUB_CG -g $RESOURCE_GROUP \
        --hub-name $IOTHUB_NAME \
        -o tsv >> log.txt
fi

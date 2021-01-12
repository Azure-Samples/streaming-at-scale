#!/bin/bash

set -euo pipefail

iothub_provisioning_aci="aci-$PREFIX-provision"

echo 'provisioning devices'
echo ". Azure Container Instance name: $iothub_provisioning_aci"
policy_name=registryReadWrite
registry_key=$(az iot hub policy show --hub-name $IOTHUB_NAME --name registryReadWrite --query primaryKey -o tsv)
iothub_cs="HostName=$IOTHUB_NAME.azure-devices.net;SharedAccessKeyName=$policy_name;SharedAccessKey=$registry_key"

az container delete -g $RESOURCE_GROUP -n $iothub_provisioning_aci --yes \
  -o tsv >> log.txt 2>/dev/null
az container create \
  --name $iothub_provisioning_aci \
  --resource-group $RESOURCE_GROUP \
  --image iottelemetrysimulator/azureiot-simulatordeviceprovisioning \
  --restart-policy Never \
  -e \
    IotHubConnectionString="$iothub_cs" \
    DevicePrefix=contoso-device-id- \
    DeviceIndex=0 \
    DeviceCount=1000 \
    -o tsv >> log.txt
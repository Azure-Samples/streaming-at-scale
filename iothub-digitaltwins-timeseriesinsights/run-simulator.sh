#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

number_of_devices=1000
events_per_second="$(($TESTTYPE * 1000 / $SIMULATOR_INSTANCES))"
interval="$((1000 * $number_of_devices / $events_per_second))"

container_registry_name=$(terraform output -raw container_registry_name)
container_registry_login_server=$(terraform output -raw container_registry_login_server)
container_registry_admin_username=$(terraform output -raw container_registry_admin_username)
container_registry_admin_password=$(terraform output -raw container_registry_admin_password)
iothub_telemetry_send_primary_connection_string=$(terraform output -raw iothub_telemetry_send_primary_connection_string)
source_code="https://github.com/algattik/Iot-Telemetry-Simulator-fixed"
image_name="data-generator-image-3:latest"
if ! az acr repository show --name $container_registry_name --image $image_name -o none 2>/dev/null; then
  az acr build --registry $container_registry_name --image $image_name -f src/IotTelemetrySimulator/Dockerfile $source_code >> log.txt
fi
echo "creating generator container instances..."
echo ". number of instances: $SIMULATOR_INSTANCES"
echo ". events/second per instance: $events_per_second"
for i in $(seq 1 $SIMULATOR_INSTANCES); do
  name="aci-$PREFIX-simulator-$i"
  az container delete -g $RESOURCE_GROUP -n "$name" --yes \
    -o tsv >> log.txt 2>/dev/null
  az container create -g $RESOURCE_GROUP -n "$name" \
    --image $container_registry_login_server/$image_name \
    --registry-login-server $container_registry_login_server \
    --registry-username $container_registry_admin_username --registry-password "$container_registry_admin_password" \
    -e \
      DeviceCount=$number_of_devices \
      DeviceIndex=0 \
      Template='{ "eventId": "$.Guid", "complexData": { "moreData0": $.moreData00, "moreData1": $.moreData01, "moreData2": $.moreData02, "moreData3": $.moreData03, "moreData4": $.moreData04, "moreData5": $.moreData05, "moreData6": $.moreData06, "moreData7": $.moreData07, "moreData8": $.moreData08, "moreData9": $.moreData09, "moreData10": $.moreData10, "moreData11": $.moreData11, "moreData12": $.moreData12, "moreData13": $.moreData13, "moreData14": $.moreData14, "moreData15": $.moreData15, "moreData16": $.moreData16, "moreData17": $.moreData17, "moreData18": $.moreData18, "moreData19": $.moreData19 }, "value": $.value, "deviceId": "$.DeviceId", "deviceSequenceNumber": $.Counter, "type": "$.type", "createdAt": "$.Time" }' \
      Interval="$interval" \
      DevicePrefix=contoso-device-id- \
      MessageCount=0 \
      Variables='[ {"name": "value", "random": true}, {"name": "moreData00", "random": true}, {"name": "moreData01", "random": true}, {"name": "moreData02", "random": true}, {"name": "moreData03", "random": true}, {"name": "moreData04", "random": true}, {"name": "moreData05", "random": true}, {"name": "moreData06", "random": true}, {"name": "moreData07", "random": true}, {"name": "moreData08", "random": true}, {"name": "moreData09", "random": true}, {"name": "moreData10", "random": true}, {"name": "moreData11", "random": true}, {"name": "moreData12", "random": true}, {"name": "moreData13", "random": true}, {"name": "moreData14", "random": true}, {"name": "moreData15", "random": true}, {"name": "moreData16", "random": true}, {"name": "moreData17", "random": true}, {"name": "moreData18", "random": true}, {"name": "moreData19", "random": true}, {"name": "Counter", "min": 0}, {"name": "type", "values": ["TEMP", "CO2"]} ]' \
    --secure-environment-variables \
      IotHubConnectionString="$iothub_telemetry_send_primary_connection_string" \
    --cpu 4 --memory 4 \
    --no-wait \
    -o tsv >> log.txt
done

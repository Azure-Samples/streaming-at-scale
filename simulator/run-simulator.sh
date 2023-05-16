#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

EVENTS_PER_SECOND=${EVENTS_PER_SECOND:-$(($TESTTYPE * 1000))}
EVENTS_PER_SECOND_PER_INSTANCE="$(($EVENTS_PER_SECOND / $SIMULATOR_INSTANCES))"

number_of_devices=1000
interval="$((1000 * $number_of_devices / $EVENTS_PER_SECOND_PER_INSTANCE))"

image_name="mcr.microsoft.com/oss/azure-samples/azureiot-telemetrysimulator"

if [ -n "${VNET_NAME:-}" ]; then
  vnet_options="--vnet $VNET_NAME --subnet producers-subnet"
else
  vnet_options=""
fi

complex_data_template=""
complex_data_variables=""
for i in $(seq 1 ${SIMULATOR_COMPLEX_DATA_COUNT:-23}); do
  variable_num=$(printf "%06d" $i)
  complex_data_template="$complex_data_template, \"moreData$i\": 0.$.var$variable_num"
  complex_data_variables="$complex_data_variables, {\"name\": \"var$variable_num\", \"random\": true}"
done

echo "creating generator container instances..."
echo ". number of instances: $SIMULATOR_INSTANCES"
echo ". events/second per instance: $EVENTS_PER_SECOND_PER_INSTANCE"
for i in $(seq 1 $SIMULATOR_INSTANCES); do
  name="aci-$PREFIX-simulator-$i"
  az container delete -g $RESOURCE_GROUP -n "$name" --yes \
    -o tsv >> log.txt 2>/dev/null
  az container create -g $RESOURCE_GROUP -n "$name" \
    --image $image_name \
    $vnet_options \
    -e \
      DeviceCount=$number_of_devices \
      DeviceIndex=0 \
      Template='{ "eventId": "$.Guid", "value": 0.$.value, "deviceId": "$.DeviceId", "deviceSequenceNumber": $.Counter, "type": "$.type", "createdAt": "$.Time", "complexData": { '"${complex_data_template:2}"' } }' \
      Interval="$interval" \
      DevicePrefix=contoso-device-id- \
      MessageCount=0 \
      Variables='[ {"name": "value", "random": true}, {"name": "Counter", "min": 0}, {"name": "type", "values": ["TEMP", "CO2"]}'"$complex_data_variables"' ]' \
      DuplicateEvery="${SIMULATOR_DUPLICATE_EVERY_N_EVENTS:-1000}" \
      PartitionKey="$.DeviceId" \
      ${SIMULATOR_VARIABLES:-} \
    --secure-environment-variables \
      "$SIMULATOR_CONNECTION_SETTING" \
    --cpu 4 --memory 4 \
    --no-wait \
    -o tsv >> log.txt
done

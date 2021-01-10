#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

REPORT_THROUGHPUT_MINUTES=${REPORT_THROUGHPUT_MINUTES:-30}

EVENTHUB_NAMESPACES=${EVENTHUB_NAMESPACES:-${EVENTHUB_NAMESPACE:-}}

if [ -n "${IOTHUB_NAME:-}" ]; then
  IOTHUB_RESOURCES=$(az iot hub show -g $RESOURCE_GROUP --name $IOTHUB_NAME --query id -o tsv)
fi

ofs=2
metric_names="IncomingMessages IncomingBytes OutgoingMessages OutgoingBytes ThrottledRequests"
iot_metric_names="d2c.telemetry.ingress.success"
fmt="%28s%12s%20s%20s%20s%20s%20s\n"

eh_resources=""
eh_number=0
echo "Reporting aggregate metrics per minute, offset by $ofs minutes, for $REPORT_THROUGHPUT_MINUTES minutes."
for EVENTHUB_NAMESPACE in $EVENTHUB_NAMESPACES; do
  eh_number=$((eh_number+1))
  echo "Event Hub #$eh_number Namespace: $EVENTHUB_NAMESPACE"
  eh_resource=$(az eventhubs namespace show -g $RESOURCE_GROUP -n "$EVENTHUB_NAMESPACE" --query id -o tsv)
  eh_resources="$eh_resources $eh_resource"
  eh_capacity=$(az eventhubs namespace show -g $RESOURCE_GROUP -n "$EVENTHUB_NAMESPACE" --query sku.capacity -o tsv)
  echo "Event Hub capacity: $eh_capacity throughput units (this determines MAX VALUE below)."
  printf "$fmt" "" "Event Hub #" $metric_names
  PER_MIN=60
  MB=1000000
  printf "$fmt" "" "-----------" $(tr -C " " "-" <<<$metric_names)
  printf "$fmt" "MAX VALUE" "Event Hub $eh_number" "$((eh_capacity*1000*PER_MIN))" "$((eh_capacity*1*MB*PER_MIN))" "$((eh_capacity*4096*PER_MIN))" "$((eh_capacity*2*MB*PER_MIN))" "-"
  printf "$fmt" "" "-----------" $(tr -C " " "-" <<<$metric_names)
done

for i in $(seq 1 $REPORT_THROUGHPUT_MINUTES) ; do
  eh_number=0
  for iothub_resource in ${IOTHUB_RESOURCES:-}; do
    metrics=$(
      az monitor metrics list --resource "$iothub_resource" --interval PT1M \
        --metrics $(tr " " "," <<< $iot_metric_names) --offset ${ofs}M \
        --query 'value[].timeseries[0].data[0].floor(total)' -o tsv
      )
    date=$(date +%Y-%m-%dT%H:%M:%S%z)
    printf "$fmt" "$date" "IoT Hub    " $metrics
  done
  for eh_resource in $eh_resources; do
    eh_number=$((eh_number+1))
    metrics=$(
      az monitor metrics list --resource "$eh_resource" --interval PT1M \
        --metrics $(tr " " "," <<< $metric_names) --offset ${ofs}M \
        --query 'value[].timeseries[0].data[0].floor(total)' -o tsv
      )
    date=$(date +%Y-%m-%dT%H:%M:%S%z)
    printf "$fmt" "$date" "Event Hub $eh_number" $metrics
  done

  # sleep until next full minute. "10#" is to force base 10 if string is e.g. "09"
  sleep "$((60 - 10#$(date +%S) ))"
done

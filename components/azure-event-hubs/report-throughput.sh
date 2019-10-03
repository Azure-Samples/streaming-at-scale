#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

REPORT_THROUGHPUT_MINUTES=${REPORT_THROUGHPUT_MINUTES:-30}

ofs=2
eh_resources=$(az eventhubs namespace show -g $RESOURCE_GROUP -n "$EVENTHUB_NAMESPACE" --query id -o tsv)
if [ -n "${EVENTHUB_NAMESPACE_OUT:-}" ]; then
  eh_resources="$eh_resources $(az eventhubs namespace show -g $RESOURCE_GROUP -n "$EVENTHUB_NAMESPACE_OUT" --query id -o tsv)"
fi
eh_capacity=$(az eventhubs namespace show -g $RESOURCE_GROUP -n "$EVENTHUB_NAMESPACE" --query sku.capacity -o tsv)
metric_names="IncomingMessages IncomingBytes OutgoingMessages OutgoingBytes ThrottledRequests"
fmt="%28s%12s%20s%20s%20s%20s%20s\n"
echo "Event Hub capacity: $eh_capacity throughput units (this determines MAX VALUE below)."
echo "Reporting aggregate metrics per minute, offset by $ofs minutes, for $REPORT_THROUGHPUT_MINUTES minutes."
printf "$fmt" "" "Event Hub #" $metric_names
PER_MIN=60
MB=1000000
printf "$fmt" "" "-----------" $(tr -C " " "-" <<<$metric_names)
printf "$fmt" "MAX VALUE" "" "$((eh_capacity*1000*PER_MIN))" "$((eh_capacity*1*MB*PER_MIN))" "$((eh_capacity*4096*PER_MIN))" "$((eh_capacity*2*MB*PER_MIN))" "-"
printf "$fmt" "" "-----------" $(tr -C " " "-" <<<$metric_names)

for i in $(seq 1 $REPORT_THROUGHPUT_MINUTES) ; do
  eh_number=0
  date=$(date +%Y-%m-%dT%H:%M:%S%z)
  for eh in $eh_resources; do
    eh_number=$((eh_number+1))
    metrics=$(
      az monitor metrics list --resource "$eh" --interval PT1M \
        --metrics $(tr " " "," <<< $metric_names) --offset ${ofs}M \
        --query 'value[].timeseries[0].data[0].floor(total)' -o tsv
      )
    printf "$fmt" "$date" "$eh_number" $metrics
  done

  # sleep until next full minute. "10#" is to force base 10 if string is e.g. "09"
  sleep "$((60 - 10#$(date +%S) ))"
done

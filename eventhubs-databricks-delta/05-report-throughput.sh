#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

eh_resource=$(az resource show -g $RESOURCE_GROUP --resource-type Microsoft.EventHub/namespaces -n "$EVENTHUB_NAMESPACE" --query id -o tsv)
metric_names="IncomingMessages IncomingBytes OutgoingMessages OutgoingBytes ThrottledRequests"
fmt="%28s%20s%20s%20s%20s%20s\n"
echo "Event Hub capacity: $EVENTHUB_CAPACITY throughput units (this determines MAX VALUE below)."
echo "Reporting aggregate metrics per minute, offset by 1 minute, for 30 minutes."
printf "$fmt" "" $metric_names
PER_MIN=60
MB=1000000
printf "$fmt" "" $(tr -C " " "-" <<<$metric_names)
printf "$fmt" "MAX VALUE" "$((EVENTHUB_CAPACITY*1000*PER_MIN))" "$((EVENTHUB_CAPACITY*1*MB*PER_MIN))" "$((EVENTHUB_CAPACITY*4096*PER_MIN))" "$((EVENTHUB_CAPACITY*2*MB*PER_MIN))" "-"
printf "$fmt" "" $(tr -C " " "-" <<<$metric_names)
for i in {1..30} ; do
  printf "$fmt" "$(date +%Y-%m-%dT%H:%M:%S%z)" $(az monitor metrics list --resource "$eh_resource" --interval PT1M --metrics $(tr " " "," <<< $metric_names) --offset 1M | jq -r '.value[] | .timeseries[0].data[0].total')
  # sleep until next full minute. "10#" is to force base 10 if string is e.g. "09"
  sleep "$((60 - 10#$(date +%S) ))"
done

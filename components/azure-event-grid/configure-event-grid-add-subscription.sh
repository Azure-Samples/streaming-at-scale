#!/bin/bash
set -euo pipefail

echo 'adding subscription to event grid'
echo "name: $EVENT_SUBSCRIPTION_NAME"
echo "endpoint: $EVENT_SUBSCRIPTION_ENDPOINT"
echo "endpoint-type: $EVENT_SUBSCRIPTION_ENDPOINT_TYPE"
#echo "filter: $EVENT_SUBSCRIPTION_FILTER"
##--advanced-filter $EVENT_SUBSCRIPTION_FILTER

az eventgrid event-subscription create \
  --source-resource-id $STORAGEID \
  --name $EVENT_SUBSCRIPTION_NAME \
  --endpoint $EVENT_SUBSCRIPTION_ENDPOINT \
  --endpoint-type $EVENT_SUBSCRIPTION_ENDPOINT_TYPE

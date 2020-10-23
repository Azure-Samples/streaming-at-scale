#!/bin/bash

set -euo pipefail

echo 'creating TSI'

az timeseriesinsights environment longterm create \
  --resource-group $RESOURCE_GROUP \
  --name $TSI_ENVIRONMENT \
  --sku-name=L1 \
  --storage-account-name=$AZURE_STORAGE_ACCOUNT \
  --time-series-id-properties='[{"name":"deviceId", "type":"string"}]' \
  -o tsv >>log.txt

es_resource_id=$(az eventhubs eventhub get -g $RESOURCE_GROUP -n $EVENTHUB_NAME --namespace-name $EVENTHUB_NAMESPACE --query id --output tsv)

az timeseriesinsights event-source eventhub create \
  --resource-group $RESOURCE_GROUP \
  --environment-name $TSI_ENVIRONMENT \
  --name $EVENTHUB_NAME \
  --event-source-resource-id $es_resource_id \
  --consumer-group-name $EVENTHUB_CG \
  --key-name Listen \
  --timestamp-property-name createdAt \
  -o tsv >>log.txt

userType=$(az account show --query user.type -o tsv)
if [ "$userType" == "user" ]; then
  echo 'Granting user access'
  az timeseriesinsights access-policy create --environment-name
    --resource-group $RESOURCE_GROUP \
    --environment-name $TSI_ENVIRONMENT \
    --name access \
    --principal-object-id "$userId" \
    --roles Contributor \
    -o tsv >>log.txt
fi

#!/bin/bash

set -euo pipefail

accessPolicyContributorObjectIds=""

userType=$(az account show --query user.type -o tsv)

if [ "$userType" == "user" ]; then

  # Get ID of current user, to grant access to TSI environment
  userId=$(az ad signed-in-user show --query objectId -o tsv)
  accessPolicyContributorObjectIds='"'$userId'"'

fi

echo 'creating TSI'
az group deployment create \
  --resource-group $RESOURCE_GROUP \
  --template-file ../components/azure-timeseriesinsights/tsi-eventhubs-arm-template.json \
  --parameters \
  environmentName=$TSI_ENVIRONMENT \
  eventHubNamespace=$EVENTHUB_NAMESPACE \
  eventHubName=$EVENTHUB_NAME \
  eventSourceKeyName=Listen \
  consumerGroupName=$EVENTHUB_CG \
  storageAccountName=$AZURE_STORAGE_ACCOUNT \
  environmentTimeSeriesIdProperties='[{"name":"deviceId", "type":"string"}]' \
  eventSourceTimestampPropertyName=createdAt \
  accessPolicyContributorObjectIds='['$accessPolicyContributorObjectIds']' \
  -o tsv >>log.txt

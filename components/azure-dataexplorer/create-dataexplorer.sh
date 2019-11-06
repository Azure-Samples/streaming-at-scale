#!/bin/bash

set -euo pipefail

echo 'creating Data Explorer cluster'
echo ". name: $DATAEXPLORER_CLUSTER"
if ! az kusto cluster show -g $RESOURCE_GROUP -n $DATAEXPLORER_CLUSTER -o none 2>/dev/null; then
    az kusto cluster create -g $RESOURCE_GROUP -n $DATAEXPLORER_CLUSTER --sku $DATAEXPLORER_SKU --capacity $DATAEXPLORER_CAPACITY \
        -o tsv >> log.txt
fi

echo 'creating Data Explorer database'
echo ". name: $DATAEXPLORER_DATABASE"
if ! az kusto database show -g $RESOURCE_GROUP -n $DATAEXPLORER_DATABASE --cluster-name $DATAEXPLORER_CLUSTER -o none 2>/dev/null; then
az kusto database create -g $RESOURCE_GROUP -n $DATAEXPLORER_DATABASE --cluster-name $DATAEXPLORER_CLUSTER \
    --soft-delete-period P365D --hot-cache-period P31D \
    -o tsv >> log.txt
fi

kustoURL=$(az kusto cluster show -g $RESOURCE_GROUP -n $DATAEXPLORER_CLUSTER --query uri -o tsv)

function kustoQuery() {
uri=$1
csl=$2
j="{}";
j=$(jq ".db=\"$DATAEXPLORER_DATABASE\"" <<< "$j")
j=$(jq ".csl=\"$csl\"" <<< "$j")

az rest --method "POST" \
    --uri "$kustoURL$uri" \
    --body "$j" \
    --resource "$kustoURL" \
    -o tsv >>log.txt
}

echo 'creating Data Explorer table'
kustoQuery "/v1/rest/mgmt" ".create table EventTable ( eventId: string, complexData: dynamic, value: string, type: string, deviceId: string, deviceSequenceNumber: long, createdAt: datetime)"
echo 'creating Data Explorer table mapping'
if ! kustoQuery "/v1/rest/mgmt" ".show table EventTable ingestion json mapping \\\"EventMapping\\\"" 2>/dev/null; then
  kustoQuery "/v1/rest/mgmt" ".create table EventTable ingestion json mapping 'EventMapping' '[ { \\\"column\\\": \\\"eventId\\\", \\\"path\\\": \\\"$.eventId\\\" }, { \\\"column\\\": \\\"complexData\\\", \\\"path\\\": \\\"$.complexData\\\" }, { \\\"column\\\": \\\"value\\\", \\\"path\\\": \\\"$.value\\\" }, { \\\"column\\\": \\\"type\\\", \\\"path\\\": \\\"$.type\\\" }, { \\\"column\\\": \\\"deviceId\\\", \\\"path\\\": \\\"$.deviceId\\\" }, { \\\"column\\\": \\\"deviceSequenceNumber\\\", \\\"path\\\": \\\"$.deviceSequenceNumber\\\" }, { \\\"column\\\": \\\"createdAt\\\", \\\"path\\\": \\\"$.createdAt\\\" } ]'"
fi

echo "getting Service Principal ID"
appId=$(az keyvault secret show --vault-name $SERVICE_PRINCIPAL_KEYVAULT -n $SERVICE_PRINCIPAL_KV_NAME-id --query value -o tsv)

# Grant service principal permissions to read Data Explorer data (used by Databricks verification job).
echo "granting service principal Data Explorer database Viewer permissions"
MAXRETRY=60
for i in $(seq 1 $MAXRETRY); do
  if kustoQuery "/v1/rest/mgmt" ".add database $DATAEXPLORER_DATABASE viewers ('aadapp=$appId')"; then
    break
  fi
  if [ "$i" == "$MAXRETRY" ]; then
    echo "Failed granting permissions" >&2
    exit 1
  fi  
  echo "Kusto permission grant failed, probably because the service principal is not yet active. Retrying ($i/$MAXRETRY)..."
  sleep 5
done

DATAEXPLORER_CONNECTION="eventhub"
echo 'creating Data Explorer Event Hub connection'
echo ". name: $DATAEXPLORER_CONNECTION"
az group deployment create \
  --resource-group $RESOURCE_GROUP \
  --template-file ../components/azure-dataexplorer/eventhub-connection-arm-template.json \
  --parameters \
  eventHubNamespace=$EVENTHUB_NAMESPACE \
  eventHubName=$EVENTHUB_NAME \
  eventHubConsumerGroupName=$EVENTHUB_CG \
  dataExplorerConnectionName=$DATAEXPLORER_CONNECTION \
  dataExplorerClusterName=$DATAEXPLORER_CLUSTER \
  dataExplorerDatabaseName=$DATAEXPLORER_DATABASE \
  dataExplorerTableName=EventTable \
  dataExplorerMappingRuleName=EventMapping \
  -o tsv >>log.txt

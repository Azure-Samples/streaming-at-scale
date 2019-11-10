#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'adding app settings for connection strings'

echo ". EventHubsConnectionString"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings EventHubsConnectionString=$EVENTHUB_CS \
    -o tsv >> log.txt

echo ". EventHubPath: $EVENTHUB_NAME"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings EventHubName=$EVENTHUB_NAME \
    -o tsv >> log.txt

echo ". ConsumerGroup: $EVENTHUB_CG"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings ConsumerGroup=$EVENTHUB_CG \
    -o tsv >> log.txt

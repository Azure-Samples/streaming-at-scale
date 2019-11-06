#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

PLAN_NAME=$PROC_FUNCTION_APP_NAME"plan"

echo 'creating app service plan'
echo ". name: $PLAN_NAME"
az appservice plan create -g $RESOURCE_GROUP -n $PLAN_NAME \
    --number-of-workers $PROC_FUNCTION_WORKERS --sku $PROC_FUNCTION_SKU --location $LOCATION \
    -o tsv >> log.txt

echo 'creating function app'
echo ". name: $PROC_FUNCTION_APP_NAME"
az functionapp create -g $RESOURCE_GROUP -n $PROC_FUNCTION_APP_NAME \
    --plan $PLAN_NAME \
    --storage-account $AZURE_STORAGE_ACCOUNT \
    -o tsv >> log.txt

echo 'building function app'
ACTIVE_TEST=$PROC_FUNCTION
FUNCTION_SRC_PATH="$PROC_PACKAGE_FOLDER/$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET-$ACTIVE_TEST/$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET"
echo ". path: $FUNCTION_SRC_PATH"
dotnet build $FUNCTION_SRC_PATH --configuration Release --runtime win-x64 >> log.txt

echo 'creating zip file'
CURDIR=$PWD
ZIPFOLDER="$FUNCTION_SRC_PATH/bin/Release/netcoreapp2.1/win-x64"
echo " .zipped folder: $ZIPFOLDER"
rm -f $PROC_PACKAGE_PATH
cd $ZIPFOLDER
zip -r $CURDIR/$PROC_PACKAGE_PATH . >> log.txt
cd $CURDIR

echo 'configuring function app deployment source'
echo ". src: $PROC_PACKAGE_PATH"
az functionapp deployment source config-zip \
    --resource-group $RESOURCE_GROUP \
    --name $PROC_FUNCTION_APP_NAME  --src $PROC_PACKAGE_PATH \
    -o tsv >> log.txt

echo 'removing local zip file'
rm -f $PROC_PACKAGE_PATH

echo 'getting shared access key'
EVENTHUB_CS=`az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name $EVENTHUB_NAMESPACE --name Listen --query "primaryConnectionString" -o tsv`

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


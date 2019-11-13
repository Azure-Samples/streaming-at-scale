#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

PLAN_NAME=$PROC_FUNCTION_APP_NAME"plan"

echo 'creating function app plan'
echo ". name: $PLAN_NAME"

if [ "${PROC_FUNCTION_SKU:0:1}" == "E" ]; then
  echo ". max burst: $PROC_FUNCTION_WORKERS"
  workers_argname="max-burst"
else
  echo ". workers: $PROC_FUNCTION_WORKERS"
  workers_argname="number-of-workers"
fi

az functionapp plan create -g $RESOURCE_GROUP -n $PLAN_NAME \
    --$workers_argname $PROC_FUNCTION_WORKERS --sku $PROC_FUNCTION_SKU --location $LOCATION \
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
dotnet build $FUNCTION_SRC_PATH --configuration Release >> log.txt

echo 'creating zip file'
CURDIR=$PWD
ZIPFOLDER="$FUNCTION_SRC_PATH/bin/Release/netcoreapp2.1"
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

echo ". DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=false"
echo "(this is set because of this https://github.com/Azure/Azure-Functions/issues/1067)"
az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=false \
    -o tsv >> log.txt

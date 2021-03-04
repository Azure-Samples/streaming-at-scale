#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

function getStorageSecretInfo() {
    #Get Connection String of Storage Account
    storageConnectionString=$(az storage account show-connection-string \
        -g $RESOURCE_GROUP \
        -n $AZURE_STORAGE_ACCOUNT \
        --query connectionString \
        -o tsv)

    if [ $1 == "connectionstring" ]; then
        echo "$storageConnectionString"

    elif [ $1 == "sastoken" ]; then

        #Set SAS Token Expiry Date, currently set expire date to 1 month later
        expiryDate=$(date -d "+1 month" +%Y-%m-%d)

        #Setup service types
        if [ -n "${SAS_TOKEN_SERVICE_TYPE}" ]; then
            #use assigned service types to create SAS token
            services=$SAS_TOKEN_SERVICE_TYPE
        else
            #default create SAS token for all (b)lob/(f)ile/(q)ueue/(t)able service types
            services="bfqt"
        fi
        #Setup resource types
        if [ -n "${SAS_TOKEN_RESOURCE_TYPE}" ]; then
            #use assigned resource types to create SAS token
            resourceTypes=$SAS_TOKEN_RESOURCE_TYPE
        else
            #default create SAS token for all (s)ervice/(c)ontainer/(o)bject resource types
            resourceTypes="sco"
        fi
        #Setup permission
        if [ -n "${SAS_TOKEN_PERMISSION}" ]; then
            #use assigned permission to create SAS token
            permission=$SAS_TOKEN_PERMISSION
        else
            #default create SAS token as full permissions (a)dd (c)reate (d)elete (l)ist (p)rocess (r)ead (u)pdate (w)rite
            permission="acdlpruw"
        fi
        #Generate Storage SAS Token
        sasToken=$(az storage account generate-sas \
                --permissions $permission \
                --account-name $AZURE_STORAGE_ACCOUNT \
                --connection-string $storageConnectionString \
                --services $services \
                --resource-types $resourceTypes \
                --expiry $expiryDate \
                -o tsv)
        echo "${sasToken}"
    elif [ $1 == "accesskey" ]; then
        #Get Access Key of Storage Account
        accessKey=$(az storage account keys list \
                -g $RESOURCE_GROUP \
                --account-name $AZURE_STORAGE_ACCOUNT \
                --query "[?keyName == 'key1'].value" \
                -o tsv)
        echo "${accessKey}"
    fi

}
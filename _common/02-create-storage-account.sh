#!/bin/bash

echo 'creating storage account'
echo ". name: $AZURE_STORAGE_ACCOUNT"

az storage account create -n $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP --sku Standard_LRS \
-o tsv >> log.txt

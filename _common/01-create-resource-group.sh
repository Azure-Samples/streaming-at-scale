#!/bin/bash

echo 'creating resource group'
echo ". name: $RESOURCE_GROUP"
echo ". location: $LOCATION"

az group create -n $RESOURCE_GROUP -l $LOCATION -o tsv \
-o tsv >> log.txt

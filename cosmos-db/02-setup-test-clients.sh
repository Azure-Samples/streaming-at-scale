#!/bin/bash

echo 'configuring storage account for test clients'
echo ". name: $AZURE_STORAGE_ACCOUNT"

echo 'creating file share'
az storage share create -n locust \
-o tsv >> log.txt

echo 'uploading simulator scripts'
az storage file upload -s locust --source ../_common/simulator.py \
-o tsv >> log.txt


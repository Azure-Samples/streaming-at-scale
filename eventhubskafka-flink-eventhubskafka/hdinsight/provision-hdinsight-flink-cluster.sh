#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source hdinsight/create-hdinsight.sh

container=flinkscriptaction

az storage container create --account-name $AZURE_STORAGE_ACCOUNT -n $container \
    -o tsv >> log.txt

az storage container policy create --account-name $AZURE_STORAGE_ACCOUNT -c $container \
    -n HDInsightRead --permissions r --expiry 2100-01-01 -o none

az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT -c $container \
    -n install-flink.sh -f hdinsight/install-flink.sh \
    -o tsv >> log.txt

script_uri=$(az storage blob generate-sas --account-name $AZURE_STORAGE_ACCOUNT -c $container \
   --policy-name HDInsightRead --full-uri -n install-flink.sh -o tsv
)

az hdinsight script-action execute -g $RESOURCE_GROUP --cluster-name $HDINSIGHT_NAME \
  --name MyCluster \
  --script-uri "$script_uri" \
  --roles workernode \
  -o tsv >> log.txt

endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

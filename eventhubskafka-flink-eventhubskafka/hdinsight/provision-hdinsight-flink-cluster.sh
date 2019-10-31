#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source hdinsight/create-hdinsight.sh

container=flinkscriptaction

echo 'creating script action storage container'
echo ". name: $container"

az storage container create --account-name $AZURE_STORAGE_ACCOUNT -n $container \
    -o tsv >> log.txt

az storage container policy create --account-name $AZURE_STORAGE_ACCOUNT -c $container \
    -n HDInsightRead --permissions r --expiry 2100-01-01 -o none

echo 'uploading script action script'

az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT -c $container \
    -n start-flink-cluster.sh -f hdinsight/script-actions/start-flink-cluster.sh \
    -o tsv >> log.txt

script_uri=$(az storage blob generate-sas --account-name $AZURE_STORAGE_ACCOUNT -c $container \
   --policy-name HDInsightRead --full-uri -n start-flink-cluster.sh -o tsv
)

echo 'running script action'

az hdinsight script-action execute -g $RESOURCE_GROUP --cluster-name $HDINSIGHT_NAME \
  --name StartFlinkCluster \
  --script-uri "$script_uri" \
  --script-parameters "'$FLINK_VERSION' '$FLINK_SCALA_VERSION'" \
  --roles workernode \
  -o tsv >> log.txt

endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`HTTPS`].location')

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

container=flinkscriptaction

echo 'creating script action storage container'
echo ". name: $container"

az storage container create --account-name $AZURE_STORAGE_ACCOUNT -n $container \
    -o tsv >> log.txt

az storage container policy create --account-name $AZURE_STORAGE_ACCOUNT -c $container \
    -n HDInsightRead --permissions r --expiry 2100-01-01 -o none

echo 'uploading script action scripts'

az storage blob upload-batch --account-name $AZURE_STORAGE_ACCOUNT \
    --source hdinsight/script-actions --destination $container \
    -o tsv >> log.txt

script_uri=$(az storage blob generate-sas --account-name $AZURE_STORAGE_ACCOUNT -c $container \
   --policy-name HDInsightRead --full-uri -n start-flink-cluster.sh -o tsv
)

echo 'running script action'

az hdinsight script-action execute -g $RESOURCE_GROUP --cluster-name $HDINSIGHT_YARN_NAME \
  --name StartFlinkCluster \
  --script-uri "$script_uri" \
  --script-parameters "'$FLINK_VERSION' '2.12'" \
  --roles workernode \
  -o tsv >> log.txt

tmpfile=$(mktemp)
az storage blob download --account-name $AZURE_STORAGE_ACCOUNT -c $HDINSIGHT_YARN_NAME -n apps/flink/flink_master.txt -f $tmpfile -o none
flink_master=$(cat $tmpfile)
rm $tmpfile

user=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_YARN_NAME -o tsv --query 'properties.computeProfile.roles[0].osProfile.linuxOperatingSystemProfile.username')
endpoint=$(az hdinsight show -g $RESOURCE_GROUP -n $HDINSIGHT_YARN_NAME -o tsv --query 'properties.connectivityEndpoints[?name==`SSH`].location')

echo ""
echo "To open the Flink JobManager Web UI, create an SSH tunnel such as:"
echo "  ssh -L 10000:$flink_master $user@$endpoint"
echo "  Password: $HDINSIGHT_PASSWORD"
echo "Then open a local web browser pointing to:"
echo "  http://localhost:10000"
echo ""

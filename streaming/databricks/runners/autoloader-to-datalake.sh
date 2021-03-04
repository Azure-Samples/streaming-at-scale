#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail
echo "start to create job"
job_jq_command="$1"
export JAR_SOURCE_PATH="./infra/Azure/databricks-monitoring/"
export JAR_TARGET_PATH="dbfs:/databricks/spark-monitoring/"
#setup databricks monitor
echo 'start to import Spark monitor library'
echo 'Create a directory for the spark monitoring related libs'
dbfs mkdirs dbfs:/databricks/spark-monitoring
# databricks fs cp --overwrite "$JAR_SOURCE_PATH" "$JAR_TARGET_PATH"
#Copy all the spark monitoring library to the destination directory
dbfs cp --overwrite --recursive "$JAR_SOURCE_PATH" "$JAR_TARGET_PATH"
#List all the Spark monitoring library
dbfs ls dbfs:/databricks/spark-monitoring/
#Show the content of Spark-monitoring script
#for debug purpose
# dbfs cat dbfs:/databricks/spark-monitoring/spark-monitoring.sh

# jar_source_path="$3"
# jar_target_path="$4"
# job_template_path="$3"
# job_template_params="$4"
echo "$job_jq_command"
echo "retrieving landing storage account key"
landingSAkey=$(az storage account keys list -g $RESOURCE_GROUP --account-name $LANDING_AZURE_STORAGE_ACCOUNT --query "[?keyName == 'key1'].value" -o tsv)
# echo "landingSAkey:$landingSAkey"

#Prepare Ingestion Storage Account Secret
echo "retrieving ingest storage account key"
ingestionSAkey=$(az storage account keys list -g $RESOURCE_GROUP --account-name $INGESTION_AZURE_STORAGE_ACCOUNT --query "[?keyName == 'key1'].value" -o tsv)
# echo "ingestionSAkey:$ingestionSAkey"

#Get Connection String of Landing Storage Account
landingConnectionString=$(az storage account show-connection-string -g $RESOURCE_GROUP -n $LANDING_AZURE_STORAGE_ACCOUNT --query connectionString -o tsv)
# echo "landingConnectionString: $landingConnectionString"

#Get log analytics
echo "get log analytics"
logAnalyticsWorkspaceId=$(az monitor log-analytics workspace show -g $RESOURCE_GROUP --workspace-name $LOG_ANALYTICS_WORKSPACE --query "customerId" -o tsv)
# echo "logAnalyticsWorkspaceId:$logAnalyticsWorkspaceId"
logAnalyticsWorkspacePrimaryKey=$(az monitor log-analytics workspace get-shared-keys --resource-group $RESOURCE_GROUP --workspace-name $LOG_ANALYTICS_WORKSPACE --query "primarySharedKey" -o tsv)
# echo "logAnalyticsWorkspacePrimaryKey:$logAnalyticsWorkspacePrimaryKey"

echo "writing Databricks secrets: $DBSSECRETSCOPENAME"
databricks secrets put --scope $DBSSECRETSCOPENAME --key source-files-secrets --string-value "$landingSAkey"
databricks secrets put --scope $DBSSECRETSCOPENAME --key target-files-secrets --string-value "$ingestionSAkey"
databricks secrets put --scope $DBSSECRETSCOPENAME --key cloud-files-connection-string --string-value "$landingConnectionString"
databricks secrets list --scope $DBSSECRETSCOPENAME

#Use Databrick-Cli create Databricks-backed secret scope for log analytics and list the created secret scope
echo "create Databricks secrets: $LogANALYTICSSCOPENAME for log monitor"
echo 'checking Databricks secrets scope exists'
declare LOG_SECRETS_SCOPE=$(databricks secrets list-scopes --output JSON | jq -e ".scopes[]? | select (.name == \"$LogANALYTICSSCOPENAME\") | .name") &>/dev/null
if [ -z "$LOG_SECRETS_SCOPE" ]; then
  echo 'creating Databricks secrets scope'
  databricks secrets create-scope --scope $LogANALYTICSSCOPENAME --initial-manage-principal users
  # databricks secrets create-scope --scope $LogANALYTICSSCOPENAME --scope-backend-type AZURE_KEYVAULT --resource-id $keyvalutId --dns-name $keyvalutDNS --initial-manage-principal users
fi
# #put log analytics id and key into secret
databricks secrets put --scope $LogANALYTICSSCOPENAME --key databrickslogworkspaceid --string-value "$logAnalyticsWorkspaceId"
databricks secrets put --scope $LogANALYTICSSCOPENAME --key databrickslogworkspacekey --string-value "$logAnalyticsWorkspacePrimaryKey"
databricks secrets list  --scope $LogANALYTICSSCOPENAME

source ../streaming/databricks/job/run-databricks-job.sh autoloader-to-datalake false "$job_jq_command"

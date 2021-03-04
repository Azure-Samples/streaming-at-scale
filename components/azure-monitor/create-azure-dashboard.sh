#!/bin/bash

set -euo pipefail

echo 'creating Ingestion Dashboard'
az group deployment create \
    --resource-group $RESOURCE_GROUP \
    --template-file "$(readConfigItem .AzureMonitor.Dashboard.MainDashboardTemplatePath)" \
    --parameters \
        DashboardName=$INGESTION_DASHBOARD_NAME \
        LandingStorageAccountName=$LANDING_STORAGE_ACCOUNT_NAME \
        IngestionStorageAccountName=$INGESTION_STORAGE_ACCOUNT_NAME \
        IngestFuncName=$PROC_FUNCTION_APP_NAME \
        ADXClusterName=$DATAEXPLORER_CLUSTER \
    -o json >> log.txt


echo 'creating Databricks Dashboard'
az group deployment create \
    --resource-group $RESOURCE_GROUP \
    --template-file "$(readConfigItem .AzureMonitor.Dashboard.DBSDashboardTemplatePath)" \
    --parameters \
        DashboardName=$DATABRICKS_DASHBOARD_NAME \
        DatabricksLogAnalyticsWorkspaceName=$LOG_ANALYTICS_WORKSPACE \
    -o json >> log.txt
    
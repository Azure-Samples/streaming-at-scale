#!/bin/bash

set -euo pipefail

echo 'creating log analytics workspace'
echo ". name: $LOG_ANALYTICS_WORKSPACE"
az group deployment create \
    --resource-group $RESOURCE_GROUP \
    --template-file "../components/azure-monitor/template.json" \
    --parameters \
        workspaceName=$LOG_ANALYTICS_WORKSPACE \
    --verbose \
    -o tsv >> log.txt


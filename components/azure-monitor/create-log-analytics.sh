#!/bin/bash

set -euo pipefail

if ! az resource show -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --resource-type Microsoft.OperationalInsights/workspaces -o none 2>/dev/null; then
  echo 'creating Log Analytics workspace'
  echo ". name: $LOG_ANALYTICS_WORKSPACE"
  az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file "../components/azure-monitor/template.json" \
    --parameters \
        workspaceName=$LOG_ANALYTICS_WORKSPACE \
    --verbose \
    -o tsv >> log.txt
fi

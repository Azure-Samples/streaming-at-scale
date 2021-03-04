#!/bin/bash

set -euo pipefail

# Template path
if [ -z "${LOG_ANALYTICS_TEMPLATE_PATH-}" ]; then
    LOG_ANALYTICS_TEMPLATE_PATH="../components/azure-monitor/template.json"
fi

# Template parameters
if [ -z "${LOG_ANALYTICS_TEMPLATE_PARAMS-}" ]; then
    LOG_ANALYTICS_TEMPLATE_PARAMS="workspaceName=$LOG_ANALYTICS_WORKSPACE"
fi

if ! az resource show -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --resource-type Microsoft.OperationalInsights/workspaces -o none 2>/dev/null; then
  echo 'creating Log Analytics workspace'
  echo ". name: $LOG_ANALYTICS_WORKSPACE"
  az group deployment create \
    --resource-group $RESOURCE_GROUP \
    --template-file $LOG_ANALYTICS_TEMPLATE_PATH \
    --parameters $LOG_ANALYTICS_TEMPLATE_PARAMS \
    --verbose \
    -o tsv >> log.txt
fi

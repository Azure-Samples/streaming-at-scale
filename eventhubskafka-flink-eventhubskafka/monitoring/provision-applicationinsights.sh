#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'provision Azure Application Insights'

if ! az monitor app-insights component show --app $APPINSIGHTS_NAME -g $RESOURCE_GROUP >/dev/null 2>&1; then
    az extension add -n application-insights >> log.txt
    az monitor app-insights component create --app $APPINSIGHTS_NAME -l $LOCATION -g $RESOURCE_GROUP >> log.txt
fi

APPINSIGHTS_INSTRUMENTATIONKEY=$(az monitor app-insights component show --app $APPINSIGHTS_NAME -g $RESOURCE_GROUP --query instrumentationKey -o tsv)
echo ". key: $APPINSIGHTS_INSTRUMENTATIONKEY"

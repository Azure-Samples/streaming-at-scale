#!/bin/bash

set -euo pipefail

# When deleting a Log Analytics workspace, its name remains unavailable for 14 days.
# This scripts generates a name with a time-based suffix in order to support automated test scenarios.
# See https://docs.microsoft.com/en-us/azure/azure-monitor/platform/delete-workspace

source ../components/utils/create-local-settings.sh

LOG_ANALYTICS_WORKSPACE=$(jq -r .'"'$PREFIX'"'.LOG_ANALYTICS_WORKSPACE local-settings.json)

if [ "$LOG_ANALYTICS_WORKSPACE" == "" ] || [ "$LOG_ANALYTICS_WORKSPACE" == "null" ]; then
  echo 'generate Log Analytics workspace name'
  export LOG_ANALYTICS_WORKSPACE=$PREFIX$(( $(date +%s) % 1000000 ))
  echo ". name: $LOG_ANALYTICS_WORKSPACE"
  jq '."'$PREFIX'".LOG_ANALYTICS_WORKSPACE="'$LOG_ANALYTICS_WORKSPACE'"' local-settings.json > local-settings.json.tmp
  mv local-settings.json.tmp local-settings.json
else
  echo "Reusing Log Analytics workspace name stored in local-settings.json"
fi

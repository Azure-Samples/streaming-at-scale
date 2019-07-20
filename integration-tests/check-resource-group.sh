#!/bin/bash

set -euo pipefail

RG_NAME="$RESOURCE_GROUP_PREFIX$SYSTEM_JOBNAME"

if R=$(az group show -n $RG_NAME --query 'tags.streaming_at_scale_generated' -o tsv); then
  if [ -z "$R" ]; then
    echo "ERROR: Resource group $RG_NAME exists, and does not have tag streaming_at_scale_generated"
    exit 1
  fi
  echo "Deleting existing resource group $RG_NAME (as it has tag streaming_at_scale_generated)"
  az group delete -y -g $RG_NAME
fi

echo "##vso[task.setVariable variable=RG_NAME;]$RG_NAME"

#!/bin/bash

set -euo pipefail

RG_NAME="$1"

if group_info=$(az group show -n $RG_NAME --query 'tags.streaming_at_scale_generated' -o tsv); then
  if [ -z "$group_info" ]; then
    echo "ERROR: Resource group $RG_NAME exists, and does not have tag streaming_at_scale_generated"
    exit 1
  fi
  echo "Deleting existing resource group $RG_NAME (as it has tag streaming_at_scale_generated)"
  az group delete -y -g $RG_NAME
fi

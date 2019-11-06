#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating azure key vault '
echo ". name: $AZURE_KEY_VAULT"


az keyvault create --name $AZURE_KEY_VAULT --resource-group $RESOURCE_GROUP --location $LOCATION --tags streaming_at_scale_generated=1 \
-o tsv >> log.txt


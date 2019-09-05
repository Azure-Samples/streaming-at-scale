#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'creating resource group'
echo ". name: $RESOURCE_GROUP"
echo ". location: $LOCATION"

az group create -n $RESOURCE_GROUP -l $LOCATION --tags streaming_at_scale_generated=1 \
-o tsv >> log.txt

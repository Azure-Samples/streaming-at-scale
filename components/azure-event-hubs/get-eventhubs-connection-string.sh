#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

namespace=$1
policy=$2

EVENTHUB_CS=$(az eventhubs namespace authorization-rule keys list -g $RESOURCE_GROUP --namespace-name "$namespace" --name "$policy" --query "primaryConnectionString" -o tsv)

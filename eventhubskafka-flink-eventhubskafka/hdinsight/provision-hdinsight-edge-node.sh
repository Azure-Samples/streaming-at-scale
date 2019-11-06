#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo 'Provision Edge Node for HDInsight'

az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $AZURE_EDGE_NODE_NAME \
  --image Canonical:UbuntuServer:16.04.0-LTS:16.04.201910310 \
  --admin-username hdiedgeuser \
  --generate-ssh-keys \
  --vnet-name $VNET_NAME --subnet ingestion-subnet \
  --tags streaming_at_scale_generated=1



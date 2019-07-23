#!/bin/bash

set -euo pipefail

az hdinsight create -t kafka -g $RESOURCE_GROUP -n $HDINSIGHT_NAME \
  -p "$HDINSIGHT_PASSWORD" --workernode-data-disks-per-node 2 \
  --storage-account $AZURE_STORAGE_ACCOUNT
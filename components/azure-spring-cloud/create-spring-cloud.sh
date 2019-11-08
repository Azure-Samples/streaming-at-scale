#!/bin/bash

set -euo pipefail

echo "creating spring cloud"
if ! az spring-cloud show -g $RESOURCE_GROUP -n $SPRING_CLOUD_NAME -o none 2>/dev/null; then
  az spring-cloud create -g $RESOURCE_GROUP -n $SPRING_CLOUD_NAME \
    -o tsv >> log.txt
fi

echo "creating spring cloud application"
if ! az spring-cloud app show -g $RESOURCE_GROUP -s $SPRING_CLOUD_NAME -n $SPRING_CLOUD_APP -o none 2>/dev/null; then
  az spring-cloud app create -g $RESOURCE_GROUP -s $SPRING_CLOUD_NAME -n $SPRING_CLOUD_APP \
    -o tsv >> log.txt
fi

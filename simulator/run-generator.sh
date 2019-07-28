#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

CONTAINER_REGISTRY=$PREFIX"acr"
EVENTS_PER_SECOND="$(($TESTTYPE * 1000))"

echo "creating container registry..."
az acr create -g $RESOURCE_GROUP -n $CONTAINER_REGISTRY --sku Basic --admin-enabled true \
    -o tsv >> log.txt
REGISTRY_LOGIN_SERVER=$(az acr show -n $CONTAINER_REGISTRY --query loginServer -o tsv)
REGISTRY_LOGIN_PASS=$(az acr credential show -n $CONTAINER_REGISTRY --query passwords[0].value -o tsv)

echo "building generator container..."
az acr build --registry $CONTAINER_REGISTRY --image generator:latest ../simulator/generator \
    -o tsv >> log.txt

echo "creating generator container instance..."
az container delete -g $RESOURCE_GROUP -n data-generator --yes \
    -o tsv >> log.txt 2>/dev/null
az container create -g $RESOURCE_GROUP -n data-generator \
    --image $REGISTRY_LOGIN_SERVER/generator:latest \
    $VNET_OPTIONS \
    --registry-login-server $REGISTRY_LOGIN_SERVER \
    --registry-username $CONTAINER_REGISTRY --registry-password "$REGISTRY_LOGIN_PASS" \
    -e \
      OUTPUT_FORMAT="$OUTPUT_FORMAT" \
      OUTPUT_OPTIONS="$OUTPUT_OPTIONS" \
      EVENTS_PER_SECOND="$EVENTS_PER_SECOND" \
      DUPLICATE_EVERY_N_EVENTS="${SIMULATOR_DUPLICATE_EVERY_N_EVENTS:-1000}" \
      COMPLEX_DATA_COUNT=7 \
    --secure-environment-variables SECURE_OUTPUT_OPTIONS="$SECURE_OUTPUT_OPTIONS" \
    --cpu 2 --memory 4 \
    -o tsv >> log.txt

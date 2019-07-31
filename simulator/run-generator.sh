#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

CONTAINER_REGISTRY=$PREFIX"acr"
NUM_CLIENTS="$(($TEST_CLIENTS / 3))"
EVENTS_PER_SECOND="$(($TESTTYPE * 1000 / $NUM_CLIENTS))"

echo "creating container registry..."
az acr create -g $RESOURCE_GROUP -n $CONTAINER_REGISTRY --sku Basic --admin-enabled true \
    -o tsv >> log.txt
REGISTRY_LOGIN_SERVER=$(az acr show -n $CONTAINER_REGISTRY --query loginServer -o tsv)
REGISTRY_LOGIN_PASS=$(az acr credential show -n $CONTAINER_REGISTRY --query passwords[0].value -o tsv)

echo "building generator container..."
az acr build --registry $CONTAINER_REGISTRY --image generator:latest ../simulator/generator \
    -o tsv >> log.txt

if [ -n "${VNET_NAME:-}" ]; then
  vnet_options="--vnet $VNET_NAME --subnet producers-subnet"
else
  vnet_options=""
fi

echo "creating generator container instances..."
echo ". number of instances: $NUM_CLIENTS"
echo ". events/second per instance: $EVENTS_PER_SECOND"
for i in $(seq 1 $NUM_CLIENTS); do
  name="data-generator-$i"
  az container delete -g $RESOURCE_GROUP -n "$name" --yes \
    -o tsv >> log.txt 2>/dev/null
  az container create -g $RESOURCE_GROUP -n "$name" \
    --image $REGISTRY_LOGIN_SERVER/generator:latest \
    $vnet_options \
    --registry-login-server $REGISTRY_LOGIN_SERVER \
    --registry-username $CONTAINER_REGISTRY --registry-password "$REGISTRY_LOGIN_PASS" \
    -e \
      OUTPUT_FORMAT="$OUTPUT_FORMAT" \
      OUTPUT_OPTIONS="$OUTPUT_OPTIONS" \
      EVENTS_PER_SECOND="$EVENTS_PER_SECOND" \
      DUPLICATE_EVERY_N_EVENTS="${SIMULATOR_DUPLICATE_EVERY_N_EVENTS:-1000}" \
      COMPLEX_DATA_COUNT=${SIMULATOR_COMPLEX_DATA_COUNT:-} \
    --secure-environment-variables SECURE_OUTPUT_OPTIONS="$SECURE_OUTPUT_OPTIONS" \
    --cpu 1 --memory 1 \
    --no-wait \
    -o tsv >> log.txt
done

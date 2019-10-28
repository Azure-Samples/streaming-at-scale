#!/bin/bash

set -euo pipefail

RG_NAME="$1"

if [ -n "${RG_NAME:-}" ]; then
  echo "Checking if RG $RG_NAME exists"
  if az group show -g "$RG_NAME" -o none 2>/dev/null; then
     echo "Deleting RG $RG_NAME"
     az group delete -y -g "$RG_NAME" --no-wait
  fi
fi

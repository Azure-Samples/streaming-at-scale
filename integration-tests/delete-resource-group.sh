#!/bin/bash

set -euo pipefail

if [ -n "${RG_NAME:-}" ]; then
  echo "Deleting RG $RG_NAME"
  az group delete -y -g "$RG_NAME" --no-wait || true
fi

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_FUNC=$(command -v func || true)
if [ -z "$HAS_FUNC" ]; then
    echo "Azure Functions Core Tools not found"
    echo "please install it as it is needed by the script"
    echo "https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local"
    exit 1
fi

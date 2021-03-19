#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_FUNCORE=$(command -v func|| true)
if [ -z "$HAS_FUNCORE" ]; then
    echo "azure function core tools not found"
    echo "please install it as described here:"
    echo "https://github.com/Azure/azure-functions-core-tools"
    exit 1
fi

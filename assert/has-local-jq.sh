#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_JQ=$(command -v jq || true)
if [ -z "$HAS_JQ" ]; then
    echo "jq not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install jq"
    echo "or as described here:"
    echo "  https://stedolan.github.io/jq/download/"
    exit 1
fi

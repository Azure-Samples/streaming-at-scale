#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_DATABRICKSCLI=$(command -v databricks || true)
if [ -z "$HAS_DATABRICKSCLI" ]; then
    echo "databricks-cli not found"
    echo "please install it as described here:"
    echo "https://github.com/databricks/databricks-cli"
    exit 1
fi

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_KUBECTL=$(command -v kubectl || true)
if [ -z "$HAS_KUBECTL" ]; then
    echo "kubectl not found"
    echo "please install it as described here:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
fi

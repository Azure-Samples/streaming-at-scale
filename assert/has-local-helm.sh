#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_HELM=$(command -v helm || true)
if [ -z "$HAS_HELM" ]; then
    echo "helm not found"
    echo "please install it as described here:"
    echo "https://helm.sh/docs/using_helm/#installing-helm"
    exit 1
fi

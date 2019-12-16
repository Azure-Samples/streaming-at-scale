#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_KUBECTL=$(command -v kubectl || true)
if [ -z "$HAS_KUBECTL" ]; then
    echo "kubectl not found. Attempting to install it..."
    az aks install-cli --client-version "$AKS_KUBERNETES_VERSION"
fi

HAS_KUBECTL=$(command -v kubectl || true)
if [ -z "$HAS_KUBECTL" ]; then
    echo "Installation failed."
    echo "please install kubectl as described here:"
    echo "https://kubernetes.io/docs/tasks/tools/install-kubectl/"
    exit 1
fi

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_TERRAFORM=$(command -v terraform || true)
if [ -z "$HAS_TERRAFORM" ]; then
    echo "terraform not found"
    echo "please install it as described here:"
    echo "https://www.terraform.io/downloads.html"
    exit 1
fi

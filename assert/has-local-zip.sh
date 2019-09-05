#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_ZIP=$(command -v zip || true)
if [ -z "$HAS_ZIP" ]; then
    echo "zip not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install zip"
    exit 1
fi

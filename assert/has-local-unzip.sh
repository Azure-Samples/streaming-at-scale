#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_UNZIP=$(command -v unzip || true)
if [ -z "$HAS_UNZIP" ]; then
    echo "unzip not found"
    echo "please install it using your package manager, for example, on Ubuntu:"
    echo "  sudo apt install unzip"
    exit 1
fi

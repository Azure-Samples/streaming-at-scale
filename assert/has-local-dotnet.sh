#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_DOTNET=$(command -v dotnet || true)
if [ -z "$HAS_DOTNET" ]; then
    echo "dotnet SDK not found"
    echo "please install it as it is needed by the script"
    echo "https://dotnet.microsoft.com/download"
    exit 1
fi

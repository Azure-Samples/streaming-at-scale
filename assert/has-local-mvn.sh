#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_MAVEN=$(command -v mvn || true)
if [ -z "$HAS_MAVEN" ]; then
    echo "mvn not found"
    echo "Please install Maven as it is needed by the script"
    echo "https://maven.apache.org/install.html"
    exit 1
fi

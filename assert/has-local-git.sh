#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_GIT=$(command -v git || true)
if [ -z "$HAS_GIT" ]; then
    echo "git not found"
    echo "please install it as described here:"
    echo "https://git-scm.com/book/en/v2/Getting-Started-Installing-Git"
    exit 1
fi

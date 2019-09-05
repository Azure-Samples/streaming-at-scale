#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo `openssl rand 5 -base64 | cut -c1-7 | tr '[:upper:]' '[:lower:]' | tr -cd '[[:alnum:]]._-'`

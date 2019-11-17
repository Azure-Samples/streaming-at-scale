#!/bin/bash

set -euo pipefail

if [ ! -e local-settings.json ]; then
  echo "{}" > local-settings.json
fi

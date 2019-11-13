#!/bin/bash

set -euo pipefail

settings_prefix=""

if [ -e local-settings.json ]; then
  settings_prefix=$(jq -r .PREFIX local-settings.json)
fi

if [ "$settings_prefix" != "$PREFIX" ]; then
  echo "{}" | jq '.PREFIX="'$PREFIX'"' > local-settings.json.tmp
  mv local-settings.json.tmp local-settings.json
fi

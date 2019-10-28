#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

HAS_AZ=$(command -v az || true)
if [ -z "$HAS_AZ" ]; then
    echo "AZ CLI not found"
    echo "please install it as described here:"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest"
    exit 1
fi

function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }

REQUIRED_AZ_VERSION=2.0.72
AZ_VERSION=$(az --version |grep ^azure-cli |head -1 |awk '{print $2}')

if version_gt "$REQUIRED_AZ_VERSION" "$AZ_VERSION" ; then
    echo "Your AZ CLI version ($AZ_VERSION) is too low, please upgrade to version >= $REQUIRED_AZ_VERSION"
    echo "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest#update"
    exit 1
fi

AZ_SUBSCRIPTION_NAME=$(az account show --query name -o tsv || true)
if [ -z "$AZ_SUBSCRIPTION_NAME" ]; then
    #az account show already shows error message "Please run 'az login' to setup account."
    exit 1
fi
echo "Using Azure subscription: $AZ_SUBSCRIPTION_NAME"

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

MASTER_IP="$1"
CLIENT_ID="$2"

echo "creating client $CLIENT_ID..."
az container delete -g $RESOURCE_GROUP -n locust-$CLIENT_ID -y \
-o tsv >> log.txt

az container create -g $RESOURCE_GROUP -n locust-$CLIENT_ID \
--image yorek/locustio --ports 8089 5557 5558 \
--azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY --azure-file-volume-share-name locust --azure-file-volume-mount-path /locust \
--command-line "locust --slave --master-host=$MASTER_IP --host https://$EVENTHUB_NAMESPACE.servicebus.windows.net -f simulator.py" \
-e EVENTHUB_KEY="$EVENTHUB_KEY" EVENTHUB_NAMESPACE="$EVENTHUB_NAMESPACE" EVENTHUB_NAME="$EVENTHUB_NAME" \
--cpu 1 --memory 1 \
-o tsv >> log.txt

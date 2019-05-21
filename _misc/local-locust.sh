#!/bin/bash

export EVENT_HUB_SAS_TOKEN="SharedAccessSignature sr=https%3A%2F%2Fdmsas003ingest.servicebus.windows.net%2Fdmsas003ingest-32&sig=KhMyKsrmVqmpL6zRTuO1LccFtXbFN51UkZPlIo83uEw%3D&se=1540229017&skn=RootManageSharedAccessKey"
export EVENT_HUB_NAMESPACE="dmsas003ingest"
export EVENT_HUB_NAME="dmsas003ingest-32"

docker build . -t locust

docker run --rm -p 8089:8089 -e EVENTHUB_SAS_TOKEN="$EVENT_HUB_SAS_TOKEN" -e EVENTHUB_NAMESPACE=$EVENT_HUB_NAMESPACE -e EVENTHUB_NAME=$EVENT_HUB_NAME locust -f simulator.py --host "https://$EVENT_HUB_NAMESPACE.servicebus.windows.net"


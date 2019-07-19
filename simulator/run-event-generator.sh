#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

SIMULATOR_DUPLICATE_EVERY_N_EVENTS=${SIMULATOR_DUPLICATE_EVERY_N_EVENTS:-1000}

echo "retrieving storage connection string"
AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP -o tsv)

echo 'creating file share'
az storage share create -n locust --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o tsv >> log.txt

echo 'uploading simulator scripts'
az storage file upload -s locust --source ../simulator/simulator.py --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o tsv >> log.txt

echo 'getting event hub key'
EVENTHUB_POLICY='Send'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list --name $EVENTHUB_POLICY --namespace-name $EVENTHUB_NAMESPACE --resource-group $RESOURCE_GROUP --query 'primaryKey' -o tsv`

echo 'create test clients'
echo ". count: $TEST_CLIENTS"

echo "deploying locust..."
LOCUST_MONITOR=$(az group deployment create -g $RESOURCE_GROUP \
	--template-file ../simulator/locust-arm-template.json \
	--query properties.outputs.locustMonitor.value -o tsv --parameters \
	eventHubNamespace=$EVENTHUB_NAMESPACE eventHubName=$EVENTHUB_NAME \
        eventHubPolicy=$EVENTHUB_POLICY eventHubKey=$EVENTHUB_KEY \
	storageAccountName=$AZURE_STORAGE_ACCOUNT fileShareName=locust \
	numberOfInstances=$TEST_CLIENTS duplicateEveryNEvents=$SIMULATOR_DUPLICATE_EVERY_N_EVENTS \
	)
sleep 10

echo ". endpoint: $LOCUST_MONITOR"

echo "starting locust swarm..."
declare USER_COUNT=$((250*$TEST_CLIENTS))
declare HATCH_RATE=$((10*$TEST_CLIENTS))
echo ". users: $USER_COUNT"
echo ". hatch rate: $HATCH_RATE"
curl -fsL $LOCUST_MONITOR/swarm -X POST -F "locust_count=$USER_COUNT" -F "hatch_rate=$HATCH_RATE"

echo 'done'
echo 'starting to monitor locusts for 20 seconds... '
sleep 5
for s in {1..10} 
do
    RPS=$(curl -s -X GET $LOCUST_MONITOR/stats/requests | jq ".stats[0].current_rps")
    echo "locust is sending $RPS messages/sec"
    sleep 2
done
echo 'monitoring done'

echo "locust monitor available at: $LOCUST_MONITOR"

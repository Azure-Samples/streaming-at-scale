#!/bin/bash

set -euo pipefail

echo 'stopping processing function'
az functionapp stop --name $PROC_FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP \
    -o tsv >> log.txt

echo "retrieving storage connection string"
AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP -o tsv)

echo 'creating file share'
az storage share create -n locust --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o tsv >> log.txt

echo 'uploading simulator scripts'
az storage file upload -s locust --source ../_common/locust/simulator.py --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o tsv >> log.txt

echo 'getting storage key'
AZURE_STORAGE_KEY=`az storage account keys list -n $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP --query '[0].value' -o tsv` 

echo 'getting event hub key'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list --name RootManageSharedAccessKey --namespace-name $EVENTHUB_NAMESPACE --resource-group $RESOURCE_GROUP --query 'primaryKey' -o tsv`

echo 'create test clients'
echo ". count: $TEST_CLIENTS"

create_master_locust() {
    CLIENT_ID="master"
    az container delete -g $RESOURCE_GROUP -n locust-$CLIENT_ID -y \
        -o tsv >> log.txt

    az container create -g $RESOURCE_GROUP -n locust-$CLIENT_ID \
        --image yorek/locustio --ports 8089 5557 5558 --ip-address public --dns-name-label $LOCUST_DNS_NAME-$CLIENT_ID \
        --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY --azure-file-volume-share-name locust --azure-file-volume-mount-path /locust \
        --command-line "locust --master --expect-slaves=$1 --host https://$EVENTHUB_NAMESPACE.servicebus.windows.net -f simulator.py" \
        -e EVENTHUB_KEY="$EVENTHUB_KEY" EVENTHUB_NAMESPACE="$EVENTHUB_NAMESPACE" EVENTHUB_NAME="$EVENTHUB_NAME" \
        --cpu 1 --memory 2 \
        -o tsv >> log.txt

    QRY="[?name=='locust-$CLIENT_ID'].[ipAddress.ip]"
    CMD="az container list -g $RESOURCE_GROUP --query $QRY -o tsv"
    LOCUST_IP=$($CMD)
    echo $LOCUST_IP
}

create_client_locust() {
    CLIENT_ID=$1
    az container delete -g $RESOURCE_GROUP -n locust-$CLIENT_ID -y \
        -o tsv >> log.txt

    az container create -g $RESOURCE_GROUP -n locust-$CLIENT_ID \
        --image yorek/locustio --ports 8089 5557 5558 \
        --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY --azure-file-volume-share-name locust --azure-file-volume-mount-path /locust \
        --command-line "locust --slave --master-host=$2 --host https://$EVENTHUB_NAMESPACE.servicebus.windows.net -f simulator.py" \
        -e EVENTHUB_KEY="$EVENTHUB_KEY" EVENTHUB_NAMESPACE="$EVENTHUB_NAMESPACE" EVENTHUB_NAME="$EVENTHUB_NAME" COMPLEX_DATA_COUNT="23" \
        --cpu 1 --memory 1 \
        -o tsv >> log.txt
}

echo "creating master locust..."
declare MASTER_IP=$(create_master_locust $TEST_CLIENTS)
echo ". endpoint: http://$MASTER_IP:8089"

echo "creating client locusts..."
for CLIENT_ID in $(seq 1 $TEST_CLIENTS)
do
    echo "creating client $CLIENT_ID..."
    create_client_locust $CLIENT_ID $MASTER_IP &
done

echo "waiting for clients to be created..."
wait
sleep 10

echo "starting locust swarm..."
declare USER_COUNT=$((250*$TEST_CLIENTS))
declare HATCH_RATE=$((10*$TEST_CLIENTS))
echo ". users: $USER_COUNT"
echo ". hatch rate: $HATCH_RATE"
curl http://$MASTER_IP:8089/swarm -X POST -F "locust_count=$USER_COUNT" -F "hatch_rate=$HATCH_RATE"

echo 'done'
echo 'starting to monitor locusts for 20 seconds... '
sleep 5
for s in {1..10} 
do
    RPS=$(curl -s -X GET http://$MASTER_IP:8089/stats/requests | jq ".stats[0].current_rps")
    echo "locust is sending $RPS messages/sec"
    sleep 2
done
echo 'monitoring done'

echo "locust monitor available at: http://$MASTER_IP:8089"

echo 'starting processing function'
az functionapp start -g $RESOURCE_GROUP -n $PROC_FUNCTION_APP_NAME \
    -o tsv >> log.txt
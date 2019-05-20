#!/bin/bash

echo "retrieving storage connection string"
AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP -o tsv)

echo 'creating file share'
az storage share create -n locust --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o tsv >> log.txt

echo 'uploading simulator scripts'
az storage file upload -s locust --source ../_common/simulator.py --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o tsv >> log.txt

echo 'getting storage key'
AZURE_STORAGE_KEY=`az storage account keys list -n $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP --query '[0].value' -o tsv` 

echo 'getting event hub key'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list --name RootManageSharedAccessKey --namespace-name $EVENTHUB_NAMESPACE --resource-group $RESOURCE_GROUP --query 'primaryKey' -o tsv`

echo 'generating event hub sas token'
EVENTHUB_SAS_TOKEN=`python3 ../_common/generate-event-hub-sas-token.py $EVENTHUB_NAMESPACE $EVENTHUB_NAME $EVENTHUB_KEY`
echo ". SAS token: $EVENTHUB_SAS_TOKEN"

echo 'create test clients'
echo ". count: $TEST_CLIENTS"

create_master_locust() {
    CLIENT_ID="master"
    az container delete -g $RESOURCE_GROUP -n locust-$CLIENT_ID -y \
    -o tsv >> log.txt

    az container create -g $RESOURCE_GROUP -n locust-$CLIENT_ID \
    --image christianbladescb/locustio --ports 8089 5557 5558 --ip-address public --dns-name-label $LOCUST_DNS_NAME-$CLIENT_ID \
    --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY --azure-file-volume-share-name locust --azure-file-volume-mount-path /locust \
    --command-line "/usr/bin/locust --master --host https://$EVENTHUB_NAMESPACE.servicebus.windows.net -f simulator.py" \
    -e EVENTHUB_SAS_TOKEN="$EVENTHUB_SAS_TOKEN" EVENTHUB_NAMESPACE="$EVENTHUB_NAMESPACE" EVENTHUB_NAME="$EVENTHUB_NAME" \
    --cpu 4 --memory 8 \
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
    --image christianbladescb/locustio --ports 8089 5557 5558 \
    --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY --azure-file-volume-share-name locust --azure-file-volume-mount-path /locust \
    --command-line "/usr/bin/locust --slave --master-host=$2 --host https://$EVENTHUB_NAMESPACE.servicebus.windows.net -f simulator.py" \
    -e EVENTHUB_SAS_TOKEN="$EVENTHUB_SAS_TOKEN" EVENTHUB_NAMESPACE="$EVENTHUB_NAMESPACE" EVENTHUB_NAME="$EVENTHUB_NAME" \
    --cpu 4 --memory 8 \
    -o tsv >> log.txt
}

echo "creating master locust..."
declare MASTER_IP=$(create_master_locust)
echo ". endpoint: http://$MASTER_IP:8089"

echo "creating client locusts..."
for CLIENT_ID in $(seq 1 $TEST_CLIENTS)
do
    echo "creating client $CLIENT_ID..."
    create_client_locust $CLIENT_ID $MASTER_IP &
done

echo "waiting for clients to be created..."
wait

echo "starting locust swarm..."
declare USER_COUNT=$((500*$TEST_CLIENTS))
declare HATCH_RATE=$((10*$TEST_CLIENTS))
curl http://$LOCUST_IP:8089/swarm -X POST -F "locust_count=$USER_COUNT" -F "hatch_rate=$HATCH_RATE"

echo 'done'
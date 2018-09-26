#!/bin/bash

echo 'stopping processing function'
az functionapp stop --name $PROC_FUNCTION_APP_NAME --resource-group $RESOURCE_GROUP \
-o tsv >> log.txt

echo 'configuring storage account for test clients'
echo ". name: $AZURE_STORAGE_ACCOUNT"

echo 'creating file share'
az storage share create -n locust \
-o tsv >> log.txt

echo 'uploading simulator scripts'
az storage file upload -s locust --source ../_common/simulator.py \
-o tsv >> log.txt

echo 'getting storage key'
AZURE_STORAGE_KEY=`az storage account keys list -n $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP --query '[0].value' -o tsv` 

echo 'getting event hub key'
EVENTHUB_KEY=`az eventhubs namespace authorization-rule keys list --name RootManageSharedAccessKey --namespace-name $EVENTHUB_NAMESPACE --resource-group $RESOURCE_GROUP --query 'primaryKey' -o tsv`

echo 'generating event hub sas token'
EVENTHUB_SAS_TOKEN=`python3 ../_common/generate-event-hub-sas-token.py $EVENTHUB_NAMESPACE $EVENTHUB_NAME $EVENTHUB_KEY`
echo ". SAS token: $EVENTHUB_SAS_TOKEN"

echo 'create test clients'
echo '. count: $TEST_CLIENTS'
for CLIENT_ID in $(seq 1 $TEST_CLIENTS)
do
    echo "creating client $CLIENT_ID..."

    az container delete -g $RESOURCE_GROUP -n locust-$CLIENT_ID -y \
    -o tsv >> log.txt

    az container create -g $RESOURCE_GROUP -n locust-$CLIENT_ID \
    --image christianbladescb/locustio --ports 8089 --ip-address public --dns-name-label $LOCUST_DNS_NAME-$CLIENT_ID \
    --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY --azure-file-volume-share-name locust --azure-file-volume-mount-path /locust \
    --command-line "/usr/bin/locust --host https://$EVENTHUB_NAMESPACE.servicebus.windows.net -f simulator.py" \
    -e EVENTHUB_SAS_TOKEN="$EVENTHUB_SAS_TOKEN" EVENTHUB_NAMESPACE="$EVENTHUB_NAMESPACE" EVENTHUB_NAME="$EVENTHUB_NAME" \
    --cpu 4 --memory 8 \
    -o tsv >> log.txt

    QRY="[?name=='locust-$CLIENT_ID'].[ipAddress.ip]"
    CMD="az container list -g $RESOURCE_GROUP --query $QRY -o tsv"
    LOCUST_IP=$($CMD)
    echo "starting client $CLIENT_ID..."
    echo ". endpoint: http://$LOCUST_IP:8089"
    sleep 15
    curl http://$LOCUST_IP:8089/swarm -X POST -F "locust_count=500" -F "hatch_rate=10"
    echo 'done'
done

echo 'starting processing function'
az functionapp start -g $RESOURCE_GROUP -n $PROC_FUNCTION_APP_NAME \
-o tsv >> log.txt
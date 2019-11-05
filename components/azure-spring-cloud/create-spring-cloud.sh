#!/bin/bash

set -euo pipefail

if false; then

echo "creating spring cloud"
if ! az spring-cloud show -g $RESOURCE_GROUP -n $SPRING_CLOUD_NAME -o none 2>/dev/null; then
  az spring-cloud create -g $RESOURCE_GROUP -n $SPRING_CLOUD_NAME \
    -o tsv >> log.txt
fi

echo "creating spring cloud application"
if ! az spring-cloud app show -g $RESOURCE_GROUP -s $SPRING_CLOUD_NAME -n $SPRING_CLOUD_APP -o none 2>/dev/null; then
az spring-cloud app create -g $RESOURCE_GROUP -s $SPRING_CLOUD_NAME -n $SPRING_CLOUD_APP \
    -o tsv >> log.txt
fi

fi

echo "creating service principal"
if ! test -e my.azureauth; then
  group_id=$(az group show -g $RESOURCE_GROUP --query id -o tsv)
  az ad sp create-for-rbac --sdk-auth --scope "$group_id" > my.tmp.azureauth
  mv my.tmp.azureauth my.azureauth
fi

server_fqdn=$(az postgres server show -g $RESOURCE_GROUP -n $POSTGRESQL_SERVER_NAME --query fullyQualifiedDomainName -o tsv)
jdbc_url="jdbc:postgresql://$server_fqdn/$POSTGRESQL_DATABASE_NAME"

echo "building application"
mvn -f spring-app verify -Pintegration-test \
  -D spring.cloud.azure.credential-file-path=file:my.azureauth \
  -D spring.cloud.azure.resource-group=$RESOURCE_GROUP \
  -D spring.cloud.azure.eventhub.namespace=$EVENTHUB_NAMESPACE \
  -D spring.cloud.azure.eventhub.checkpoint-storage-account=$AZURE_STORAGE_ACCOUNT \
  -D spring.datasource.url=$jdbc_url \
  -D spring.datasource.username=serveradmin@$POSTGRESQL_SERVER_NAME \
  -D eventHubName=$EVENTHUB_NAME \
  -D eventHubConsumerGroup=$EVENTHUB_CG \


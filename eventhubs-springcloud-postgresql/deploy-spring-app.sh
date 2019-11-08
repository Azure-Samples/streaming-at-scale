#!/bin/bash

set -euo pipefail

echo "creating service principal"
azureauthFile=spring-app/src/main/resources/my.azureauth
if ! test -e "$azureauthFile"; then
  group_id=$(az group show -g $RESOURCE_GROUP --query id -o tsv)
  az ad sp create-for-rbac --sdk-auth --scope "$group_id" > "$azureauthFile.tmp"
  mv "$azureauthFile.tmp" "$azureauthFile"
fi

echo "Getting PostgreSQL endpoint"
server_fqdn=$(az postgres server show -g $RESOURCE_GROUP -n $POSTGRESQL_SERVER_NAME --query fullyQualifiedDomainName -o tsv)
jdbc_url="jdbc:postgresql://$server_fqdn/$POSTGRESQL_DATABASE_NAME"

echo "building application"
mvn -f spring-app package

echo "deploying application"
az spring-cloud app deploy -g $RESOURCE_GROUP -s $SPRING_CLOUD_NAME -n $SPRING_CLOUD_APP \
  --jar-path spring-app/target/eventhubs-to-postgresql-0.0.1-SNAPSHOT.jar \
  --env \
    spring.cloud.azure.resource-group=$RESOURCE_GROUP \
    spring.cloud.azure.eventhub.namespace=$EVENTHUB_NAMESPACE \
    spring.cloud.azure.eventhub.checkpoint-storage-account=$AZURE_STORAGE_ACCOUNT \
    spring.datasource.url=$jdbc_url \
    spring.datasource.username=serveradmin@$POSTGRESQL_SERVER_NAME \
    spring.datasource.password="$POSTGRESQL_ADMIN_PASS" \
    eventHubName=$EVENTHUB_NAME \
    eventHubConsumerGroup=$EVENTHUB_CG \
  -o tsv >> log.txt

#!/bin/bash

set -euo pipefail

echo "retrieving storage account key"
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

echo "retrieving server FQDN"
server_fqdn=$(az postgres server show -g $RESOURCE_GROUP -n $POSTGRESQL_SERVER_NAME --query fullyQualifiedDomainName -o tsv)
jdbcUrl="jdbc:postgresql://$server_fqdn/$POSTGRESQL_DATABASE_NAME"


echo "deploying azure postgres"
echo ". server: $POSTGRESQL_SERVER_NAME"
echo ". database: $POSTGRESQL_DATABASE_NAME"

# Create a logical server in the resource group
if false; then
az postgres server create \
    --name $POSTGRESQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --admin-user serveradmin \
    --admin-password "$POSTGRESQL_ADMIN_PASS" \
    --sku-name "$POSTGRESQL_SKU" \
    -o tsv >> log.txt

echo "Enabling access from Azure"
az postgres server firewall-rule create \
    --resource-group $RESOURCE_GROUP \
    --server $POSTGRESQL_SERVER_NAME \
    -n AllowAllWindowsAzureIps \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    -o tsv >> log.txt

echo "deploying PostgreSQL db"
az postgres db create --resource-group "$RESOURCE_GROUP" \
    --server $POSTGRESQL_SERVER_NAME \
    --name $POSTGRESQL_DATABASE_NAME \
    -o tsv >> log.txt

echo 'creating file share'
az storage share create -n dbprovision --account-name $AZURE_STORAGE_ACCOUNT \
    -o tsv >> log.txt
fi

echo 'uploading provisioning scripts'
az storage file upload-batch --source ../components/azure-postgresql/provision/ \
    --destination dbprovision --account-name $AZURE_STORAGE_ACCOUNT \
    -o tsv >> log.txt

echo 'running provisioning scripts in container instance'
instanceName="dbprovision-$(uuidgen | tr A-Z a-z)"
az container create -g $RESOURCE_GROUP -n "$instanceName" \
    --image flyway/flyway:6.0.8 \
    --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY \
    --azure-file-volume-share-name dbprovision --azure-file-volume-mount-path /flyway/sql \
    --environment-variables FLYWAY_URL=$jdbcUrl FLYWAY_DATABASE=$POSTGRESQL_DATABASE_NAME FLYWAY_USER=serveradmin@$POSTGRESQL_SERVER_NAME \
    --secure-environment-variables FLYWAY_PASSWORD="$POSTGRESQL_ADMIN_PASS" \
    --command-line "/flyway/flyway migrate" \
    --cpu 1 --memory 1 \
    --restart-policy Never \
    -o tsv >> log.txt

TIMEOUT=60
for i in $(seq 1 $TIMEOUT); do
  containerState=$(az container show  -g $RESOURCE_GROUP -n "$instanceName" --query instanceView.state -o tsv)
  case "state_$containerState" in
    state_Pending|state_Running) : ;;
    *)                           break;;
  esac
done

if [ "$containerState" != "Succeeded" ]; then
  az container show -g $RESOURCE_GROUP -n "$instanceName"
  az container logs -g $RESOURCE_GROUP -n "$instanceName"
fi

echo 'deleting container instance'
az container delete -g $RESOURCE_GROUP -n "$instanceName" --yes \
    -o tsv >> log.txt

if [ "$containerState" != "Succeeded" ]; then
  echo "SQL provisioning FAILED"
  exit 1
fi

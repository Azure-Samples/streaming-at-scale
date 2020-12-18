#!/bin/bash

set -euo pipefail

echo "retrieving storage connection string"
AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name $AZURE_STORAGE_ACCOUNT -g $RESOURCE_GROUP -o tsv)
AZURE_STORAGE_KEY=$(az storage account keys list -g $RESOURCE_GROUP -n $AZURE_STORAGE_ACCOUNT -o tsv --query "[0].value")

echo "deploying azure sql"
echo ". server: $SQL_SERVER_NAME"
echo ". database: $SQL_DATABASE_NAME"

# Create a logical server in the resource group
echo "creating logical server"
az sql server create \
    --name $SQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP \
    --admin-user serveradmin \
    --admin-password "$SQL_ADMIN_PASS" \
    -o json >> log.txt

echo "enabling access from Azure"
# Configure a firewall rule for the server
az sql server firewall-rule create \
    --resource-group $RESOURCE_GROUP \
    --server $SQL_SERVER_NAME \
    -n AllowAllWindowsAzureIps \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 \
    -o json >> log.txt

echo "deploying database $SQL_TYPE"
az sql $SQL_TYPE create --resource-group "$RESOURCE_GROUP" \
    --server $SQL_SERVER_NAME \
    --name $SQL_DATABASE_NAME \
    --service-objective $SQL_SKU \
    -o json >> log.txt

echo 'creating file share'
az storage share create -n sqlprovision --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o json >> log.txt

echo 'uploading provisioning scripts'
echo 'uploading provision.sh...'
az storage file upload --source ../components/azure-sql/provision/provision.sh \
    --share-name sqlprovision --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o json >> log.txt
echo "uploading $SQL_TYPE/provision.sql..."
az storage file upload --source ../components/azure-sql/provision/$SQL_TYPE/provision.sql \
    --share-name sqlprovision --connection-string $AZURE_STORAGE_CONNECTION_STRING \
    -o json >> log.txt

echo 'running provisioning scripts in container instance'
instanceName="sqlprovision-$(openssl rand -base64 8 | cut -c1-8 | tr '[:upper:]' '[:lower:]' | tr -cd '[[:alnum:]]._-')"
az container create -g $RESOURCE_GROUP -n "$instanceName" \
    --image mcr.microsoft.com/mssql-tools:v1 \
    --azure-file-volume-account-name $AZURE_STORAGE_ACCOUNT --azure-file-volume-account-key $AZURE_STORAGE_KEY \
    --azure-file-volume-share-name sqlprovision --azure-file-volume-mount-path /sqlprovision \
    --command-line "bash ./sqlprovision/provision.sh" \
    --environment-variables SQL_SERVER_NAME=$SQL_SERVER_NAME SQL_DATABASE_NAME=$SQL_DATABASE_NAME \
    --secure-environment-variables SQL_ADMIN_PASS="$SQL_ADMIN_PASS" \
    --cpu 1 --memory 1 \
    --restart-policy Never \
    -o json >> log.txt

echo "waiting for sql provisioning to finish..."

TIMEOUT=180
for i in $(seq 1 $TIMEOUT); do
  containerState=$(az container show -g $RESOURCE_GROUP -n "$instanceName" --query instanceView.state -o tsv)
  echo "container state: $containerState"
  case "state_$containerState" in
    state_Pending|state_Running): sleep 5s;;
    *) break;;
  esac
done

echo "sql provisioning state: $containerState"

if [ "$containerState" != "Succeeded" ]; then
  az container logs  -g $RESOURCE_GROUP -n "$instanceName"
fi

echo 'deleting container instance'
az container delete -g $RESOURCE_GROUP -n "$instanceName" --yes \
    -o json >> log.txt

if [ "$containerState" != "Succeeded" ]; then  
  exit 1
fi

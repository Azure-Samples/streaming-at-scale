#!/bin/bash

echo 'adding app settings for connection strings'
echo ". function: $PROC_FUNCTION_APP_NAME"

AZURESQL_CONNSTR="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Persist Security Info=False;User ID=serveradmin;Password=Strong_Passw0rd!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az functionapp config appsettings set --name $PROC_FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --settings AzureSQLConnectionString=$AZURESQL_CONNSTR \
    -o tsv >> log.txt


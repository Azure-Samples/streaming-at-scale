#!/bin/bash

echo 'adding app settings for connection strings'
echo ". function: $PROC_FUNCTION_APP_NAME"

ACS="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Persist Security Info=False;User ID=serveradmin;Password=Strong_Passw0rd!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
echo ". AzureSQLConnectionString: $ACS"

az functionapp config appsettings set \
    -n $PROC_FUNCTION_APP_NAME \
    -g $RESOURCE_GROUP \
    --settings AzureSQLConnectionString="$ACS" \
    -o tsv >> log.txt
SYNAPSE_WORKSPACE=$PREFIX"-synwkspc"
echo "Creating Azure Synapse Workspace $SYNAPSE_WORKSPACE"

az synapse workspace create --name $SYNAPSE_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --storage-account $AZURE_STORAGE_ACCOUNT_GEN2 \
  --file-system $FILE_SYSTEM \
  --sql-admin-login-user $SQL_ADMIN_USER \
  --sql-admin-login-password $SQL_ADMIN_PASSWORD \
  --location $LOCATION

echo "Creating Azure Synapse Spark Pools"
az synapse spark pool create --name $SYNAPSE_SPARKPOOL \
  --workspace-name $SYNAPSE_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --spark-version $SPARK_VERSION \
  --node-count 3 \
  --node-size Small 
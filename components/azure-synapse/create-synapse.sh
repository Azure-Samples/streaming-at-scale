SYNAPSE_WORKSPACE=$PREFIX"-synwkspc"
SQL_ADMIN_PASSWORD=$1
WORKSPACE_NAME_EXIST=$(az synapse workspace check-name --name $SYNAPSE_WORKSPACE --query "available")

if [ "$WORKSPACE_NAME_EXIST" = false ];then 
  echo "Synapse Workspace $SYNAPSE_WORKSPACE already exists"
  exit 0
fi
echo "Creating Azure Synapse Workspace $SYNAPSE_WORKSPACE"
az synapse workspace create --name $SYNAPSE_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --storage-account $AZURE_STORAGE_ACCOUNT_GEN2 \
  --file-system $FILE_SYSTEM \
  --sql-admin-login-user $SQL_ADMIN_USER \
  --sql-admin-login-password $SQL_ADMIN_PASSWORD \
  --location $LOCATION

SYNAPSE_WORKSPACE_ID=$(az synapse workspace show --name $SYNAPSE_WORKSPACE --resource-group $RESOURCE_GROUP | jq -r '.identity.principalId')

# Get subscription Id
SUBSCRIPTION_ID=$(az account show | jq -r '.id')
STORAGE_ACCOUNT_URL="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$AZURE_STORAGE_ACCOUNT_GEN2"

az role assignment create --assignee "$SYNAPSE_WORKSPACE_ID" \
--role "Storage Blob Data Contributor" \
--scope "$STORAGE_ACCOUNT_URL"

# Creating a notebook requires a firewall rule to allow access to Azure Synapse Workspace from your machine
WorkspaceWeb=$(az synapse workspace show --name $SYNAPSE_WORKSPACE --resource-group $RESOURCE_GROUP | jq -r '.connectivityEndpoints | .web')
WorkspaceDev=$(az synapse workspace show --name $SYNAPSE_WORKSPACE --resource-group $RESOURCE_GROUP | jq -r '.connectivityEndpoints | .dev')
ClientIP=$(curl -sb -H "Accept: application/json" "$WorkspaceDev" | jq -r '.message')
ClientIP=${ClientIP##'Client Ip address : '}

echo "Creating a firewall rule to enable access for IP address: $ClientIP"
FIREWALL_RULE_NAME="Allow Client IP"

az synapse workspace firewall-rule create --end-ip-address $ClientIP \
  --start-ip-address $ClientIP \
  --name "Allow Client IP" \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $SYNAPSE_WORKSPACE

echo "Creating Azure Synapse Spark Pools"
az synapse spark pool create --name $SYNAPSE_SPARKPOOL \
  --workspace-name $SYNAPSE_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --spark-version $SPARK_VERSION \
  --node-count $SPARK_NODE_COUNT \
  --node-size $SPARK_NODE_SIZE 

echo "Creating Synapse Avro to Delta Notebook"
az synapse notebook create --workspace-name $SYNAPSE_WORKSPACE \
  --name "blob-avro-to-delta-synapse" \
  --file @"../streaming/synapse/notebooks/blob-avro-to-delta-synapse.ipynb" \
  --spark-pool-name $SYNAPSE_SPARKPOOL

echo "Creating Synapse Verify Delta Notebook"
az synapse notebook create --workspace-name $SYNAPSE_WORKSPACE \
--name "verify-delta" \
--file @"../streaming/synapse/notebooks/verify-delta.ipynb" \
--spark-pool-name $SYNAPSE_SPARKPOOL

# The eventHubsNamespace and eventHubName are used to set the base path for the blob trigger.
# And since these are parameters dynamically passed in when creating resources, 
# we construct the path from these values and use jq to replace the defaults in the trigger file with new dynamically created path.
tmp=$(mktemp)
jq --arg a "${STORAGE_ACCOUNT_URL}" '.properties.typeProperties.scope = $a' $SAMPLE_TRIGGER_FILE > "$tmp" && mv "$tmp" $TRIGGER_FILE

BLOB_BASE_PATH="/streamingatscale/blobs/capture/$eventHubsNamespace/$eventHubName"
jq --arg a "${BLOB_BASE_PATH}" '.properties.typeProperties.blobPathBeginsWith = $a' $TRIGGER_FILE > "$tmp" && mv "$tmp" $TRIGGER_FILE

BLOBS_FOLDER_PATH="streamingatscale/capture/$eventHubsNamespace/$eventHubName"
jq --arg a "${BLOBS_FOLDER_PATH}" '.folder_path = $a' $AVRO_TO_DELTA_PIPELINE_PARAMETER_FILE > "$tmp" && mv "$tmp" $TEMP_PIPELINE_PARAMETER_FILE

SYNAPSE_WORKSPACE="sas-ess-test-synwkspc"
SQL_ADMIN_USER="sasesssyn"
SYNAPSE_SPARKPOOL="sasesssparkpool"
SPARK_VERSION="2.4"
SYNAPSE_WORKSPACE=$PREFIX"-synwkspc"
SQL_ADMIN_PASSWORD=$1

echo "Creating Azure Synapse Workspace $SYNAPSE_WORKSPACE"
az synapse workspace create --name $SYNAPSE_WORKSPACE \
  --resource-group $RESOURCE_GROUP \
  --storage-account $AZURE_STORAGE_ACCOUNT_GEN2 \
  --file-system streamingatscale \
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

echo "Creating Synapse Notebook"
az synapse notebook create --workspace-name $SYNAPSE_WORKSPACE \
  --name "blob-avro-to-delta-synapse" \
  --file @"../streaming/synapse/notebooks/blob-avro-to-delta-synapse.ipynb" \
  --spark-pool-name $SYNAPSE_SPARKPOOL

az synapse pipeline create --workspace-name $SYNAPSE_WORKSPACE \
  --name "blob-avro-to-delta-synapse" --file @"../streaming/synapse/pipelines/blob-avro-to-delta-synapse.json"

tmp=$(mktemp)
# Replaces the value of scope in the trigger json with the above STORAGE_ACCOUNT_URL
TRIGGER_PATH="../streaming/synapse/triggers/"
TEMPLATE_TRIGGER_FILE="trg_blob-avro-to-delta-synapse.json"
TEMP_TRIGGER_FILE="temp-avro-to-delta-trigger.json"
jq --arg a "${STORAGE_ACCOUNT_URL}" '.properties.typeProperties.scope = $a' $TRIGGER_PATH$TEMPLATE_TRIGGER_FILE > "$tmp" && mv "$tmp" $TRIGGER_PATH$TEMP_TRIGGER_FILE

# The eventHubsNamespace and eventHubName are used to set the base path for the blob trigger.
# And since these are parameters dynamically passed in when creating resources, 
# we construct the path from these values and use jq to replace the defaults in the trigger file with new dynamically created path.
BLOB_BASE_PATH="/streamingatscale/blobs/capture/$eventHubsNamespace/$eventHubName"
jq --arg a "${BLOB_BASE_PATH}" '.properties.typeProperties.blobPathBeginsWith = $a' $TRIGGER_PATH$TEMP_TRIGGER_FILE > "$tmp" && mv "$tmp" $TRIGGER_PATH$TEMP_TRIGGER_FILE

az synapse trigger create --workspace-name $SYNAPSE_WORKSPACE \
  --name "avro-to-delta-trigger" --file @"$TRIGGER_PATH$TEMP_TRIGGER_FILE"

#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "Getting VNET ids..."
databricks_vnet_name="databricks-vnet"
databricks_vnet_id=$(az network vnet show -g $RESOURCE_GROUP -n $databricks_vnet_name --query id --out tsv)
hdinsight_vnet_id=$(az network vnet show -g $RESOURCE_GROUP -n $VNET_NAME --query id --out tsv)

echo "Peering Databricks VNet to HDInsight VNet..."
az network vnet peering create \
  --name "DatabricksToHDInsight" \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $databricks_vnet_name \
  --remote-vnet $hdinsight_vnet_id \
  --allow-vnet-access \
  -o tsv >> log.txt

echo "Peering HDInsight VNet to Databricks VNet..."
az network vnet peering create \
  --name "HDInsightToDatabricks" \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --remote-vnet $databricks_vnet_id \
  --allow-vnet-access \
  -o tsv >> log.txt

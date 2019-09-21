#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

databricksResourceGroup=${DATABRICKS_VNET_RESOURCE_GROUP:-$RESOURCE_GROUP}

echo "Getting VNET ids"
databricks_vnet_name="databricks-vnet"
databricks_vnet_id=$(az network vnet show -g $databricksResourceGroup -n $databricks_vnet_name --query id --out tsv)
hdinsight_vnet_id=$(az network vnet show -g $RESOURCE_GROUP -n $VNET_NAME --query id --out tsv)
hdinsight_peering_name="HDInsightToDatabricks-$databricksResourceGroup-$databricks_vnet_name"

if az network vnet peering show -g $databricksResourceGroup -n "DatabricksToHDInsight" --vnet-name $databricks_vnet_name -o none 2> /dev/null; then
  echo "Deleting Databricks VNet peering"
  az network vnet peering delete -g $databricksResourceGroup -n "DatabricksToHDInsight" --vnet-name $databricks_vnet_name
fi

if az network vnet peering show -g $RESOURCE_GROUP -n "$hdinsight_peering_name" --vnet-name $VNET_NAME -o none 2> /dev/null; then
  echo "Deleting HDInsight VNet peering"
  az network vnet peering delete -g $RESOURCE_GROUP -n "$hdinsight_peering_name" --vnet-name $VNET_NAME
fi

echo "Peering Databricks VNet to HDInsight VNet"
az network vnet peering create -g $databricksResourceGroup -n "DatabricksToHDInsight" \
  --vnet-name $databricks_vnet_name --remote-vnet $hdinsight_vnet_id \
  --allow-vnet-access \
  -o tsv >> log.txt

echo "Peering HDInsight VNet to Databricks VNet"
az network vnet peering create -g $RESOURCE_GROUP -n "$hdinsight_peering_name" \
  --vnet-name $VNET_NAME --remote-vnet $databricks_vnet_id \
  --allow-vnet-access \
  -o tsv >> log.txt

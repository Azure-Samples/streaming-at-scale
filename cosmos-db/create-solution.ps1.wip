$subscription = "TE Account - DaMauri"
$resourceGroupName = "sastest"
$location = "East US"

$ctx = Set-AzureRmContext -Subscription $subscription -Name "StreamingAtScale" -Force

$rg = New-AzureRmResourceGroup -Name $resourceGroup -Location $location -Force

#Set-AzureRmDefault -ResourceGroupName $resourceGroup 

$strg = New-AzureRmStorageAccount -Name "${resourceGroup}storage" -ResourceGroupName $resourceGroupName -Location $location -SkuName "Standard_LRS" 

New-AzureRmEventHubNamespace -Name "${resourceGroup}eventhubs" -ResourceGroupName $resourceGroupName -Location $location -SkuName "Standard" -SkuCapacity 8 

New-AzureRmEventHub -Name "${resourceGroup}eventhub" -ResourceGroupName $resourceGroupName -Namespace "${resourceGroup}eventhubs" -PartitionCount 32 -MessageRetentionInDays 1  

New-AzureStorageShare -Name "locust" -Context $strg.Context
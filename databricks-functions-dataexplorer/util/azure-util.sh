#!/bin/bash
# [datalake-databricks-function-dataexplore]

# Strict mode, fail on any error
set -euo pipefail

# creates storage infrastructure for the solution
function buildBasicInfraDatalake() {
    if [ "$1" == "landing" ]; then
        resourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
    elif [ "$1" == "ingestion" ]; then
        resourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
    fi
    
    # build parameters
    allParameters=("DatalakeName=$resourceName")
    allParameters+=("Location=$(readConfigItem .Location)")
    allParameters+=("StorageSku=$(readConfigItem .Storage.StorageSku)")
    allParameters+=("AccessTier=$(readConfigItem .Storage.AccessTier)")
    allParameters+=("FileSystemName=$(readConfigItem .Storage.FileSystemName)")
    allParameters+=("FileSystemNameRootFolder=$(readConfigItem .Storage.FileSystemNameRootFolder)")
    allParameters+=("TelemetryLogfileRetentionDays=$(readConfigItem .Storage.TelemetryLogfileRetentionDays)")

    if [ "$1" == "landing" ]; then
        allParameters+=("ErrorHandleFileSystemName=$(readConfigItem .Storage.LandingErrorHandleFileSystemName)")
    elif [ "$1" == "ingestion" ]; then
        allParameters+=("ErrorHandleFileSystemName=$(readConfigItem .Storage.IngestionRetryEndInFailContainerName)")
    fi    

    # return parameters
    echo "${allParameters[@]}"
}

function getDatabricksParams() {   
    # parameters
    # resourceName, Location, Sku, KeyVaultName, AadObjectId
    dbsKeyVaultName=("$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.DatabricksKeyVaultName)")
    allParameters=("WorkspaceName=$ADB_WORKSPACE")
    allParameters+=("Location=$(readConfigItem .Location)")
    allParameters+=("Sku=$(readConfigItem .Databricks.WorkspaceSku)")
    allParameters+=("KeyVaultName=$dbsKeyVaultName")
    allParameters+=("AadObjectId=$1)")   

    # return parameters
    echo "${allParameters[@]}"
}

function getDatabricksJobParams() {     
    secret_scope_param="$(readConfigItem .Databricks.DBSSecretScopeName)"
    landing_sa_param="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
    ingestion_sa_param="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
    container_param="$(readConfigItem .Storage.FileSystemName)"
    root_folder_param="$(readConfigItem .Storage.FileSystemNameRootFolder)"
    target_folder_param="$(readConfigItem .Storage.AzureStorageTargetFolder)"
    check_point_folder_param="$(readConfigItem .DatabricksJob.AzureStorageCheckPointFolder)"
    bad_record_folder_param="$(readConfigItem .Storage.LandingBadRecordFolder)"
    queue_name_list_param="$(getQueues)"
    log_secret_scope_param="$(readConfigItem .LogAnalytics.SecretScope)"
    # min_workers_param="$(readConfigItem .DatabricksJob.DatabricksMinWorkersCount)"
    # max_workers_param="$(readConfigItem .DatabricksJob.DatabricksMaxWorkersCount)"
    source_stream_folder="abfss://$container_param@$landing_sa_param.dfs.core.windows.net/$root_folder_param"
    target_file_folder="abfss://$container_param@$ingestion_sa_param.dfs.core.windows.net/$target_folder_param"
    chekc_point_location="abfss://$container_param@$landing_sa_param.dfs.core.windows.net/$check_point_folder_param"
    bad_records_path="abfss://$container_param@$landing_sa_param.dfs.core.windows.net/$bad_record_folder_param"
    job_jq_command="$(cat <<JQ
        .notebook_task.base_parameters."secretscope"="$secret_scope_param"      
        | .notebook_task.base_parameters."source_stream_folder"="$source_stream_folder"
        | .notebook_task.base_parameters."target_file_folder"="$target_file_folder"
        | .notebook_task.base_parameters."chekc_point_location"="$chekc_point_location"
        | .notebook_task.base_parameters."triger_process_time"="$(readConfigItem .DatabricksJob.triger_process_time)"
        | .notebook_task.base_parameters."max_files"="$(readConfigItem .DatabricksJob.max_files)"
        | .notebook_task.base_parameters."queue_name_list"="$queue_name_list_param"
        | .notebook_task.base_parameters."bad_records_path"="$bad_records_path"
        | .notebook_task.base_parameters."source_stream_storage_account"="$landing_sa_param"
        | .notebook_task.base_parameters."target_file_storage_account"="$ingestion_sa_param"
        | .new_cluster.autoscale."min_workers"=$(readConfigItem .DatabricksJob.DatabricksMinWorkersCount)
        | .new_cluster.autoscale."max_workers"=$(readConfigItem .DatabricksJob.DatabricksMaxWorkersCount)
        | .new_cluster.spark_env_vars."LOG_ANALYTICS_WORKSPACE_ID"="{{secrets/$log_secret_scope_param/$(readConfigItem .LogAnalytics.SecretScopeKeyWorkspaceId)}}"
        | .new_cluster.spark_env_vars."LOG_ANALYTICS_WORKSPACE_KEY"="{{secrets/$log_secret_scope_param/$(readConfigItem .LogAnalytics.SecretScopeKeyWorkspaceKey)}}"
        
        
JQ
)"
echo "$job_jq_command"
}

function getQueues() {
    queueNameList=""
    queue_num="$(readConfigItem .EventGrid.LandingEventQueueCount)"
    LandingEventQueueName="$(readConfigItem .EventGrid.LandingEventQueueName)"
    for((i=0;i<$queue_num;i++))
    do
        queueNameList[i]="$LandingEventQueueName$i"
    done
    echo "${queueNameList[@]}" | tr ' ' ,
}

# creates event grid and storage queue infrastructure
function createEventGridStorageQueue() {
    resourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
    echo "Creating event grid ${resourceName} ..."
    
    # build parameters
    allParameters=("EventSubName=${resourceName}-subscription")
    allParameters+=("TopicStorageAccountName=$resourceName")
    allParameters+=("SubStorageAccountName=$resourceName")
    allParameters+=("SubQueueName=$(readConfigItem .EventGrid.LandingEventQueueName)")
    allParameters+=("Location=$(readConfigItem .Location)")
    allParameters+=("TriggerContainerName=$(readConfigItem .Storage.FileSystemName)")
    allParameters+=("TirggerFolderName=$(readConfigItem .Storage.FileSystemNameRootFolder)")
    allParameters+=("EventType=$(readConfigItem .EventGrid.EventTypeCreate)")
    allParameters+=("EventQueueCount=$(readConfigItem .EventGrid.LandingEventQueueCount)")
    allParameters+=("DefaultFilters=$(readConfigItem .EventGrid.LandingEventFilters nostrip)")
    allParameters+=("IsFunctionTriggerSource=false")

    # build arguments
    args=(--resource-group "$(readConfigItem .ResourceGroupName)" \
      --template-file "$(readConfigItem .EventGrid.EventGridTemplatePath)" \
      --parameters "${allParameters[@]}" \
      --name "LandingEventGridDeployment"
    )

    # run deployment
    az deployment group create "${args[@]}" -o tsv >> log.txt

    resourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
    echo "Creating event grid ${resourceName} ..."
    
    # build parameters
    allParameters=("EventSubName=${resourceName}-subscription")
    allParameters+=("TopicStorageAccountName=$resourceName")
    allParameters+=("SubStorageAccountName=$resourceName")
    allParameters+=("SubQueueName=$(readConfigItem .EventGrid.IngestionEventQueueName)")
    allParameters+=("Location=$(readConfigItem .Location)")
    allParameters+=("TriggerContainerName=$(readConfigItem .Storage.FileSystemName)")
    allParameters+=("TirggerFolderName=$(readConfigItem .Storage.AzureStorageTargetFolder)")
    allParameters+=("EventType=$(readConfigItem .EventGrid.EventTypeCreate)")
    allParameters+=("EventQueueCount=$(readConfigItem .EventGrid.IngestionEventQueueCount)")
    allParameters+=("DefaultFilters=$(readConfigItem .EventGrid.IngestionEventFilters nostrip)")
    allParameters+=("IsFunctionTriggerSource=true")

    # advanced filters require some manipulation
    AdvancedFilters="$(readConfigItem .EventGrid.IngestionEventAdvancedFilters nostrip)"
    IngestionEventAdvancedFilterJson='{"filters":'"$AdvancedFilters"'}'
    allParameters+=("AdvancedFilters=$IngestionEventAdvancedFilterJson")
    
    #build arguments
    args=(--resource-group "$(readConfigItem .ResourceGroupName)" \
      --template-file "$(readConfigItem .EventGrid.EventGridTemplatePath)" \
      --parameters "${allParameters[@]}" \
      --name "IngestionEventGridDeployment"
    )

    # run deployment
    az deployment group create "${args[@]}" -o tsv >> log.txt
}

# creates Log Analytics arm template parameters for the solution
function buildLogAnalytics() {
   
    # build parameters for Log Analytics
    allParameters=("WorkspaceName=$LOG_ANALYTICS_WORKSPACE")
    allParameters+=("Location=$LOCATION")
    allParameters+=("ServiceTier=$(readConfigItem .LogAnalytics.ServiceTier)")

    # return parameters
    echo "${allParameters[@]}"
}

# creates ingestion function
function createIngestionFunction() {
    FuncLOCATION=$LOCATION
    #"Southeast Asia"
    #set up parameters for ingestion function arm template
    resourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Functions.IngestionFunction.FunctionName)"
    allParameters=("FunctionName=$resourceName")
    allParameters+=("KeyVaultName=$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.KeyVaultName)")
    allParameters+=("IngestionStorageAccountName=$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)")
    allParameters+=("IngestionEventQueueName=$(readConfigItem .EventGrid.IngestionEventQueueName)")
    allParameters+=("IngestionConnectingStringName=$(readConfigItem .Functions.IngestionFunction.IngestionConnectingStringName)")
    allParameters+=("LeadClusterName=$(readConfigItem .ResourceGroupName)$(readConfigItem .ADX.ClusterName)")
    allParameters+=("FunctionLocation=$FuncLOCATION")
    allParameters+=("Runtime=$(readConfigItem .Functions.IngestionFunction.Runtime)")
    allParameters+=("DatabaseIDKey=$(readConfigItem .Functions.IngestionFunction.DatabaseIDKey)")
    allParameters+=("TableIDKey=$(readConfigItem .Functions.IngestionFunction.TableIDKey)")
    allParameters+=("IsFlushImmediately=$(readConfigItem .Functions.IngestionFunction.IsFlushImmediately)")
    allParameters+=("IsDuplicateCheck=$(readConfigItem .Functions.IngestionFunction.IsDuplicateCheck)")
    allParameters+=("IngestionEventQueueCount=$(readConfigItem .EventGrid.IngestionEventQueueCount)")       
    # allParameters+=("STORAGE_TABLE_ACCOUNT=$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.TableStorageAccountName)")
    # return parameters
    echo "${allParameters[@]}"

    #build arguments
    args=(--resource-group "$(readConfigItem .ResourceGroupName)" \
      --template-file "$(readConfigItem .Functions.IngestionFunction.IngestionfuncTemplatePath)" \
      --parameters "${allParameters[@]}" \
      --name "IngestionFunctionDeployment"
    )

    # run deployment
    az deployment group create "${args[@]}" -o tsv >> log.txt
    echo "function($resourceName) deployed successfully!"
}

#Update KeyVault Access Policy for Function
function updateKeyvaultPolicy() {
    echo "start to update function KeyVault Access Policy!"
    funresourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Functions.IngestionFunction.FunctionName)"
    funresourceName+="0"
    allParameters=("FunctionName=$funresourceName")
    allParameters+=("KeyVaultName=$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.KeyVaultName)")
    echo "${allParameters[@]}"
    #build arguments
    args=(--resource-group "$(readConfigItem .ResourceGroupName)" \
      --template-file "$(readConfigItem .KeyVault.KeyVaultAccessTemplatePath)" \
      --parameters "${allParameters[@]}" \
      --name "KeyVaultAccessPolicyUpdate"
    )
    
    # run deployment
    az deployment group create "${args[@]}" -o tsv >> log.txt
    echo "function KeyVault Access Policy updated!"
}

#Deploy function code
function deployFunctionCode(){
    #TODO: Add current kusolab publish methid. but should change
    #TODO: to az functionapp deployment to align with SAS repo
    echo "INFO" "Start to deploy IngestionFunction"    
    resourceName="$(readConfigItem .ResourceGroupName)$(readConfigItem .Functions.IngestionFunction.FunctionName)"
    resourceName+='0'
    path="$(readConfigItem .Functions.IngestionFunction.Path)"
    echo "path:$path"
    projectFolder="./functions/$path/__app__"
    echo "projectFolder:$projectFolder"
    functionFolder="$(readConfigItem .Functions.IngestionFunction.FunctionFolder)"
    echo "functionFolder:$functionFolder"
    targetFunJson="$projectFolder/$functionFolder/function.json"
    cp "$projectFolder/$functionFolder/function.json.template" $targetFunJson
    #update trigger queue    
    triggerQueueName="$(readConfigItem .EventGrid.IngestionEventQueueName)"
    search="@TRIGGER_QUEUE_NAME"
    replace="$triggerQueueName"
    sed -i "s/$search/$replace/" $targetFunJson
    PROC_PACKAGE_PATH="$projectFolder/$functionFolder"
    echo ". src: $PROC_PACKAGE_PATH"
    # echo 'creating zip file'
    # # ZIPFOLDER="$FUNCTION_SRC_PATH/Release/$RELFOLDER"
    # ZIPFOLDER="$projectFolder/$functionFolder"
    # zip -r $ZIPFOLDER . >> log.txt
    # echo " .zipped folder: $ZIPFOLDER"
    # # rm -f $PROC_PACKAGE_PATH
    cd $projectFolder
    

    echo 'configuring function app deployment source'  
    #PROC_PACKAGE_PATH
    func azure functionapp publish $resourceName --python 
     
    # az functionapp deployment source config \
    #     --resource-group $RESOURCE_GROUP \
    #     --name $resourceName  --src $ZIPFOLDER \
    #     --cd-app-type "Python"\
    #     -o tsv >> log.txt

    # echo 'removing local zip file'
    # rm -f $PROC_PACKAGE_PATH
    #     # Publish-Azure-Function-Deployment $path $functionFolder $triggerQueueName $resourceName
    echo "Deploy Ingestion Function Successfully!"    
    cd ../../../
    rm -f $targetFunJson
}


function getSecretPair() {
    #Declare a associative array and put secret name and value into array        
    declare -A secretMap    
    #Get Connection String of Ingesiton Storage Account
    export AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
    ingestionConnectionString=$(getStorageSecretInfo connectionstring)
    export SAS_TOKEN_SERVICE_TYPE="bq" #only create for blob/queue services
    export SAS_TOKEN_RESOURCE_TYPE="" #use default resource type in getStorageSecretInfo function
    export SAS_TOKEN_PERMISSION="" #use default permission in getStorageSecretInfo function
    ingestionSasToken=$(getStorageSecretInfo sastoken)
    
    #Get Connection String of Log Table Storage Account
    export AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.TableStorageAccountName)"
    logTableConnectionString=$(getStorageSecretInfo connectionstring)
    export SAS_TOKEN_SERVICE_TYPE="t" #only create for table services
    logTableSasToken=$(getStorageSecretInfo sastoken)
    
    #these were previously static but now are dynamic as well
    secretMap["adxclientid"]="$1"
    secretMap["adxclientsecret"]="$2"
    secretMap["aadtenantid"]="$3"
    
    #dynamic items from configuration
    secretMap["ingestiontoken"]=$ingestionSasToken
    secretMap["logtabletoken"]=$logTableSasToken
    secretMap["ingestionconnectingstring"]=$ingestionConnectionString   

    echo $(combineSecretPair secretMap)
}

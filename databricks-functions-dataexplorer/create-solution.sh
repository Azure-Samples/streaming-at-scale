#!/bin/bash
# [datalake-databricks-function-dataexplorer]
#  this solution will create
#  default steps: CIDMPFTV: 
#  1. C:common resource including resource group, Data landing and ingestion data lake storage, key vault
#  2. I:Ingestion. EventGrid and storage queue
#  3. D: Create data explorer and database, tables and data explorer
#  4. M: Monitor - Creae log analytics workspace to monitor databricks, function, data explorer, and storage
#  5. P:Process - Azure databricks to parition the data by devideId(ex:device-id-1554) and type(ex:CO2)
#  6. F:Function - Deploy Azure Function to ingest data into data explorer
#  7. T:Test - generate test data
#  8. V:Evaluate - evaluate results in data explorer

# Strict mode, fail on any error
set -euo pipefail

on_error() {
    set +e
    echo "There was an error, execution halted" >&2
    echo "Error at line $1"
    exit 1
}

trap 'on_error $LINENO' ERR

# minimum set of variables for this solution to work
export CONFIG_FILE_NAME="infra/script/config/provision-config.json"
export TESTTYPE="1"
export STEPS="CIDMPFTV"

usage() { 
    echo "Usage: $0 -f <config-file-path> [-s <steps>] [-t <test-type>]" 1>&2; 
    echo "-s: specify which steps should be executed. Default=$STEPS" 1>&2; 
    echo "    Possible values:" 1>&2; 
    echo "      C=COMMON" 1>&2; 
    echo "      I=INGESTION" 1>&2; 
    echo "      D=DATABASE" 1>&2; 
    echo "      P=PROCESSING" 1>&2; 
    echo "      T=TEST clients" 1>&2; 
    echo "      M=METRICS reporting"
    echo "-f: path to the provisioning config file. Default=$CONFIG_FILE_NAME"
    exit 1; 
}

# Initialize parameters specified from command line
while getopts ":f:s:t:" arg; do
	case "${arg}" in
		f)
			CONFIG_FILE_NAME=${OPTARG}
			;;
		s)
			STEPS=${OPTARG}
			;;
		t)
			TESTTYPE=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

# ---- Check pre-requisits for the system to work.
echo "Checking pre-requisites..."
source ../assert/has-local-az.sh
source ../assert/has-local-jq.sh
source ../assert/has-local-databrickscli.sh
source ../assert/has-local-funcoretool.sh

# ---- Parse parameters from config file to fill out environment variables
echo "Parsing configuration file $CONFIG_FILE_NAME"

# sourcing the utility file 
source ./util/script-util.sh
source ./util/azure-util.sh

# reading configuration settings into environment variables
# ---- BEGIN: SET THE VALUES IN CONFIG FILE TO CORRECTLY HANDLE THE WORKLOAD

export PREFIX="$(readConfigItem .ResourceGroupName)"
export RESOURCE_GROUP="$(readConfigItem .ResourceGroupName)"
export LOCATION="$(readConfigItem .Location)"
export TENANT_ID="$(az account show --query tenantId -o tsv)"
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
# ---- END: SET THE VALUES TO CORRECTLY HANDLE THE WORLOAD

if [[ -z "$PREFIX" ]]; then
	  echo "Enter a app name in config file for this deployment."
	  usage
fi

default_prefix="Azure Resource Group Name"
echo "**$default_prefix**"
if [[ "$PREFIX" == "$default_prefix" ]]; then
	  echo "Enter a app name in config file for this deployment."
	  usage
fi

# remove log.txt if exists
rm -f log.txt

echo
echo "Streaming at Scale with EventGrid, Databricks, Function, and DataExplorer"
echo "====================================================="
echo

echo "Steps to be executed: $STEPS"
echo

echo "Configuration: "
echo ". Resource Group  => $RESOURCE_GROUP"
echo ". Region          => $LOCATION"
echo ". Subscription    => $SUBSCRIPTION_ID"
echo ". Tenant          => $TENANT_ID"
echo

echo "Deployment started..."
echo

echo "***** Setting up credentials for the solution"
# create rg needs to be here because the SPN created below is saved in a KV that needs an RG.
source ../components/azure-common/create-resource-group.sh 

# create (or reuse) a service principal for the solution
export SERVICE_PRINCIPAL_KEYVAULT="$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.KeyVaultName)"
export SERVICE_PRINCIPAL_KV_NAME="$(readConfigItem .ResourceGroupName)Databricks-ADX-SPId"

# create service principal and associated assets.
echo "***** Try to create service principal"
source ../components/azure-common/create-service-principal.sh

# this returns SP_CLIENT_ID and SP_CLIENT_SECRET environment variables
source ../components/azure-common/get-service-principal-data.sh
echo "Client id is $SP_CLIENT_ID"
echo

# perform assignment
ASSIGNMENT=$(az role assignment create --assignee $SP_CLIENT_ID --scope "/subscriptions/$SUBSCRIPTION_ID" --role "Contributor")

echo "assign role to clientid $SP_CLIENT_ID completed"
echo

echo "***** [C] Setting up COMMON resources"
    # create resource group    
    # create azure data lake storage account (dbinput and dboutput)
    # create key vault
    # update key vault
    
    RUN=`echo $STEPS | grep C -o || true`
    if [ ! -z "$RUN" ]; then
        # common storage acct parameters
        export AZURE_STORAGE_TEMPLATE_PATH="$(readConfigItem .Storage.DatalakeTemplatePath)"

        # create landing storage account
        export AZURE_STORAGE_ACCOUNT_GEN2="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
        export AZURE_STORAGE_TEMPLATE_PARAMS="$(buildBasicInfraDatalake landing)"
        echo "Try to create data lake storage v2 - landing"
        source ../components/azure-storage/create-storage-hfs.sh # create storage
        
        # create ingestion storage account
        export AZURE_STORAGE_ACCOUNT_GEN2="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
        export AZURE_STORAGE_TEMPLATE_PARAMS="$(buildBasicInfraDatalake ingestion)"
        echo "Try to create data lake storage v2 - ingestion"
        source ../components/azure-storage/create-storage-hfs.sh # create storage

        # create log table storage account
        export AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.TableStorageAccountName)"
        echo "Try to create storage - log table"
        source ../components/azure-storage/create-storage-account.sh # create storage
        
        # create functions key vault
        export AZURE_KEY_VAULT_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.KeyVaultName)"
        export AZURE_KEY_VAULT_AAD_OBJECTID="$SP_CLIENT_OBJECTID"
        source ../components/azure-keyvault/create-key-vault.sh     
        source ../components/azure-keyvault/configure-key-vault-access-policy.sh

        # update key vault with SPN id/secret, datalake connection string and SAS token for Ingestion Azure Function
        # include the get storage secret info function code
        source ../components/azure-storage/get-storage-secret-info.sh
        
        # Use getSecretPair function to compose the key vault secret pair parameters
        export UPDATE_KEYVAULT_SECRET_PARAMETERS="$(getSecretPair $SP_CLIENT_ID $SP_CLIENT_SECRET $TENANT_ID)"
        echo "UPDATE_KEYVAULT_SECRET_PARAMETERS: $UPDATE_KEYVAULT_SECRET_PARAMETERS"
        export UPDATE_KEYVAULT_SECRET_TEMPLATE_PATH="$(readConfigItem .KeyVault.KeyVaultSecretTemplatePath)"
        source ../components/azure-keyvault/update-key-vault.sh

        # create databricks key vault
        export AZURE_KEY_VAULT_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.DatabricksKeyVaultName)"
        source ../components/azure-keyvault/create-key-vault.sh
        source ../components/azure-keyvault/configure-key-vault-access-policy.sh        
    fi
echo

echo "***** [I] Setting up INGESTION eventgrid and related storage queues"
    # create event grid and storage queue    

    export EVENT_GRID_SYSTEM_TOPIC_NAME=$PREFIX"ingestiontopic"
    export EVENT_GRID_SYSTEM_TOPIC_TYPE="microsoft.storage.storageaccounts"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        createEventGridStorageQueue
    fi
echo

echo "***** [D] Setting up DATAEXPLORER"
    # create data explorer
    # create data explorer databases

    export DATAEXPLORER_CLUSTER=$PREFIX"$(readConfigItem .ADX.ClusterName)"
    echo "***** ADX DATAEXPLORER_CLUSTER: $DATAEXPLORER_CLUSTER"

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then      
        source ../components/azure-dataexplorer/create-dataexplorer.sh "-s C"
        #TODO: update adx policy to be able to view data for user
        echo "***** ADX created successully"
        echo "***** Start to create database and table"
        #Set Env variable 
        export RETENTION_DAYS="$(readConfigItem .ADX.TableRetentionDays)"    
        export CLIENT_ID="$SP_CLIENT_ID"
        export CLIENT_SECRET="$SP_CLIENT_SECRET"
        export REGION="$LOCATION"
        export CLUSTER_NAME="$DATAEXPLORER_CLUSTER"
        export RESOURCE_GROUP="$RESOURCE_GROUP"
        export DATABASE_NUM="$(readConfigItem .ADX.DatabaseNum)"

        export scriptpath="./tools/create-dataexplorer-database"
        pip install -r "$scriptpath/requirements.txt"
        python "$scriptpath/create_dataexplorer_database.py" createDatabase -s "$scriptpath/FieldList" -c $DATABASE_NUM
        python "$scriptpath/create_dataexplorer_database.py" createTableofDatabase -s "$scriptpath/FieldList" -c $DATABASE_NUM
    fi
echo

echo "***** [M] Starting METRICS reporting"
    # create LOG_ANALYTICS workspace
    # create dashboard for databricks
    # create dashboard for data lake storage, function and data explorer

    export INGESTION_DASHBOARD_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .AzureMonitor.Dashboard.MainDashboardName)"
    export DATABRICKS_DASHBOARD_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .AzureMonitor.Dashboard.DBSDashboardName)"

    export LANDING_STORAGE_ACCOUNT_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
    export INGESTION_STORAGE_ACCOUNT_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
    export PROC_FUNCTION_APP_NAME="$(readConfigItem .ResourceGroupName)$(readConfigItem .Functions.IngestionFunction.FunctionName)"

    export LOG_ANALYTICS_WORKSPACE="$(readConfigItem .ResourceGroupName)$(readConfigItem .LogAnalytics.WorkspaceName)"
    export LOG_ANALYTICS_TEMPLATE_PATH="$(readConfigItem .LogAnalytics.ARMTemplatePath)"
    export LOG_ANALYTICS_TEMPLATE_PARAMS="$(buildLogAnalytics)"

    RUN=`echo $STEPS | grep M -o || true`
    if [ ! -z "$RUN" ]; then
         source ../components/azure-monitor/create-log-analytics.sh
         source ../components/azure-monitor/create-azure-dashboard.sh
    fi
echo

echo "***** [P] Setting up PROCESSING"
    # create databricks
    # deploy notebooks in databricks
    # create databricks job

    echo "Start to deploy databricks"
    export ADB_WORKSPACE="$(readConfigItem .ResourceGroupName)$(readConfigItem .Databricks.WorkspaceName)"
    echo "ADB_WORKSPACE: $ADB_WORKSPACE"
    export ADB_TOKEN_KEYVAULT="$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.DatabricksKeyVaultName)"
    
    RUN=`echo $STEPS | grep P -o || true`
    if [ ! -z "$RUN" ]; then

        export AZURE_DATABRICKS_TEMPLATE_PATH="$(readConfigItem .Databricks.DBSTemplatePath)"        
        export AZURE_DATABRICKS_TEMPLATE_PARAMS="$(getDatabricksParams $SP_CLIENT_OBJECTID)"
        export AZURE_DBSJOB_TEMPLATE_PATH="$(readConfigItem .DatabricksJob.DatabricksJobParamPath)"
        export LANDING_AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
        export INGESTION_AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.IngestionDatalakeName)"
        export DATABRICKS_SPARKVERSION="$(readConfigItem .DatabricksJob.DatabricksSparkVersion)"
        export DATABRICKS_NODETYPE="$(readConfigItem .DatabricksJob.DatabricksNodeSpec)"
        export DATABRICKS_WORKERS="$(readConfigItem .DatabricksJob.DatabricksMinWorkersCount)"
        export DBSSECRETSCOPENAME="$(readConfigItem .Databricks.DBSSecretScopeName)"
        export LogANALYTICSSCOPENAME="$(readConfigItem .LogAnalytics.SecretScope)"
        # print parameters
        echo ". Databricks      => VM: $DATABRICKS_NODETYPE, Workers: $DATABRICKS_WORKERS"
        printParameters "${AZURE_DATABRICKS_TEMPLATE_PARAMS[@]}"    

        tempfile="./infra/Azure/databricks-monitoring/spark-monitoring.sh.template"
        outputFile="./infra/Azure/databricks-monitoring/spark-monitoring.sh"
        sed "s/\bsubscription_id_param\b/$SUBSCRIPTION_ID/g" $tempfile > $outputFile
        sed -i "s/\group_name_param\b/$RESOURCE_GROUP/g" $outputFile
        sed -i "s/\db_workspace_name_param\b/$LOG_ANALYTICS_WORKSPACE/g" $outputFile
        sed -i "s/\r$//" $outputFile

        # create databricks
        source ../components/azure-databricks/create-databricks.sh
        echo "start to create databricks job"
        # get params for databricks jobs
        jobparams="$(getDatabricksJobParams)"
        echo "jobparams:$jobparams"
        source ../streaming/databricks/runners/autoloader-to-datalake.sh "$jobparams"
    fi
echo

echo "***** [F] Setting up ingestion function"
    # create function
    # create keyvault policy for function to access
    # deploy function code

    echo "Start to set up ingestion function"

    RUN=`echo $STEPS | grep F -o || true`
    if [ ! -z "$RUN" ]; then
        #create function service
        createIngestionFunction
        #update function keyvault policy 
        updateKeyvaultPolicy
        #deploy function code
        deployFunctionCode        
    fi
echo


echo "***** [T] Starting up TEST clients"
    # use python script to generate test data
    echo "Start to run data generator"
    #TODO: Modify modify data generator to dump data to data lake storage
    RUN=`echo $STEPS | grep T -o || true`
    if [ ! -z "$RUN" ]; then        
        echo "***** clean up adx for testing"
        #Set Env variable 
        export RETENTION_DAYS="$(readConfigItem .ADX.TableRetentionDays)"    
        export CLIENT_ID="$SP_CLIENT_ID"
        export CLIENT_SECRET="$SP_CLIENT_SECRET"
        export REGION="$LOCATION"
        export CLUSTER_NAME="$DATAEXPLORER_CLUSTER"
        export RESOURCE_GROUP="$RESOURCE_GROUP"
        export DATABASE_NUM="$(readConfigItem .ADX.DatabaseNum)"
        export scriptpath="./tools/evaluation"
        pip install -r "$scriptpath/requirements.txt"
        python "$scriptpath/cleanup_adx_all_db_records.py"
        python "$scriptpath/count_adx_all_db_records.py"

        echo "***** start to simulate data"
        # include the get storage secret info function code
        export AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
        
        source ../components/azure-storage/get-storage-secret-info.sh
        echo "AZURE_STORAGE_ACCOUNT: $AZURE_STORAGE_ACCOUNT"
        landingkey=$(getStorageSecretInfo accesskey)

        echo "start to gen fake data"
        export scriptpath="./tools/fakedata-generator"
        pip install -r "$scriptpath/requirements.txt"
        container="$(readConfigItem .Storage.FileSystemName)"
        folder="$(readConfigItem .Storage.FileSystemNameRootFolder)"
        batch_file_count=1
        record_count=10
        interval=1
        maximal_count=2
        targte_result=$[$record_count*$maximal_count]
        echo "expected to generate $targte_result records"
        python "$scriptpath/fake_data_generator.py" -fc $batch_file_count -c $record_count -i $interval -m $maximal_count -ta $AZURE_STORAGE_ACCOUNT -tk $landingkey -tc $container -tf $folder 
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"
    # verify the results in data explorer
    WAITTIME="5m"
    RUN=`echo $STEPS | grep V -o || true`
    if [ ! -z "$RUN" ]; then
        echo "wait $WAITTIME mins..."
        sleep $WAITTIME
        echo "***** do deployment VERIFICATION"
        #Set Env variable 
        export RETENTION_DAYS="$(readConfigItem .ADX.TableRetentionDays)"    
        export CLIENT_ID="$SP_CLIENT_ID"
        export CLIENT_SECRET="$SP_CLIENT_SECRET"
        export REGION="$LOCATION"
        export CLUSTER_NAME="$DATAEXPLORER_CLUSTER"
        export RESOURCE_GROUP="$RESOURCE_GROUP"
        export DATABASE_NUM="$(readConfigItem .ADX.DatabaseNum)"
        export scriptpath="./tools/evaluation"
        pip install -r "$scriptpath/requirements.txt"
        python "$scriptpath/count_adx_all_db_records.py"
    fi
echo

echo "***** Done"
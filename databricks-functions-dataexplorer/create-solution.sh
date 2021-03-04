#!/bin/bash
# [datalake-databricks-function-dataexplorer]

#  1. Data landing place: data lake storage
#  2. Databricks autoloader for streaming
#  3. Databricks partition data by devideId(ex:device-id-1554) and type(ex:CO2)
#  3. Azure Function ingest data into data explorer pipeline
#  8. Generate sample data for testing
#  9. Evaluate results in data explorer

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
    echo "-t: test 1,5,10 thousands msgs/sec. Default=$TESTTYPE"
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
#TODO: add azure core tool check
echo "azure core tool needed to install..."

# ---- Parse parameters from config file to fill out environment variables
echo "Parsing configuration file $CONFIG_FILE_NAME"

# sourcing the utility file 
source ./util/script-util.sh
source ./util/azure-util.sh

# reading configuration settings into environment variables
export PREFIX="$(readConfigItem .ResourceGroupName)"
export RESOURCE_GROUP="$(readConfigItem .ResourceGroupName)"
export LOCATION="$(readConfigItem .Location)"
export TENANT_ID="$(az account show --query tenantId -o tsv)"
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

if [[ -z "$PREFIX" ]]; then
	  echo "Enter a name for this deployment."
	  usage
fi

# ---- BEGIN: SET THE VALUES TO CORRECTLY HANDLE THE WORKLOAD
# ---- HERE'S AN EXAMPLE USING DATABRICKS, FUNCTION AND DATA EXPLORER

# 10000 messages/sec
if [ "$TESTTYPE" == "10" ]; then
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=36 # must be 1, 3, 6 or a multiple or 6
    export SIMULATOR_INSTANCES=5
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=16
    export DATABRICKS_MAXEVENTSPERTRIGGER=70000
    export PROC_FUNCTION=Ingestion
    export PROC_FUNCTION_SKU=EP2
    export PROC_FUNCTION_WORKERS=10
    export DATAEXPLORER_SKU=Standard_D13_v2
    export DATAEXPLORER_CAPACITY=3
    export SIMULATOR_INSTANCES=5
fi

# 5000 messages/sec
if [ "$TESTTYPE" == "5" ]; then
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=24 # must be 1, 3, 6 or a multiple or 6
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=16
    export DATABRICKS_MAXEVENTSPERTRIGGER=70000
    export SIMULATOR_INSTANCES=3
    export PROC_FUNCTION=Ingestion
    export PROC_FUNCTION_SKU=EP2
    export PROC_FUNCTION_WORKERS=8
    export DATAEXPLORER_SKU=Standard_D12_v2
    export DATAEXPLORER_CAPACITY=2
    export SIMULATOR_INSTANCES=3
fi

# 1000 messages/sec
if [ "$TESTTYPE" == "1" ]; then
    export PROC_JOB_NAME=streamingjob
    export PROC_STREAMING_UNITS=6 # must be 1, 3, 6 or a multiple or 6
    export SIMULATOR_INSTANCES=1
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=4
    export DATABRICKS_MAXEVENTSPERTRIGGER=10000
    export PROC_FUNCTION=Ingestion
    export PROC_FUNCTION_SKU=EP2
    export PROC_FUNCTION_WORKERS=2
    export DATAEXPLORER_SKU=Standard_D11_v2
    export DATAEXPLORER_CAPACITY=2
    export SIMULATOR_INSTANCES=1
fi

# ---- END: SET THE VALUES TO CORRECTLY HANDLE THE WORLOAD

# last checks and variables setup
if [ -z ${SIMULATOR_INSTANCES+x} ]; then
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
#echo ". EventHubs       => TU: $EVENTHUB_CAPACITY, Partitions: $EVENTHUB_PARTITIONS"
echo ". Databricks      => VM: $DATABRICKS_NODETYPE, Workers: $DATABRICKS_WORKERS, maxEventsPerTrigger: $DATABRICKS_MAXEVENTSPERTRIGGER"
echo ". Function        => Name: $PROC_FUNCTION, SKU: $PROC_FUNCTION_SKU, Workers: $PROC_FUNCTION_WORKERS"
echo ". Simulators      => $SIMULATOR_INSTANCES"
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
echo "Client id is $SP_CLIENT_SECRET"
echo

# perform assignment
ASSIGNMENT=$(az role assignment create --assignee $SP_CLIENT_ID --scope "/subscriptions/$SUBSCRIPTION_ID" --role "Contributor")

echo "Client id is $SP_CLIENT_ID"
echo "Client object id is $SP_CLIENT_OBJECTID"
echo

echo "***** [C] Setting up COMMON resources"
    # create resource group
    # create key vault
    # create azure data lake storage account (dbinput and dboutput)
    # create databricks
    # create autoloader for databricks
    # create ingestion function
    # configure ingestion function
    # create data explorer
    # configure data explorer    
    # variables to call shared components
    
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
    export EVENT_GRID_SYSTEM_TOPIC_NAME=$PREFIX"ingestiontopic"
    export EVENT_GRID_SYSTEM_TOPIC_TYPE="microsoft.storage.storageaccounts"

    RUN=`echo $STEPS | grep I -o || true`
    if [ ! -z "$RUN" ]; then
        createEventGridStorageQueue
    fi
echo

echo "***** [D] Setting up DATAEXPLORER"    
    export DATAEXPLORER_CLUSTER=$PREFIX"$(readConfigItem .ADX.ClusterName)"
    echo "***** ADX DATAEXPLORER_CLUSTER: $DATAEXPLORER_CLUSTER"
    # export SERVICE_PRINCIPAL_KV_NAME=$DATAEXPLORER_CLUSTER"-reader"
    # export SERVICE_PRINCIPAL_KEYVAULT=$PREFIX"spkv"    

    RUN=`echo $STEPS | grep D -o || true`
    if [ ! -z "$RUN" ]; then
        #source ../components/azure-common/create-service-principal.sh        
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
    echo "Start to deploy databricks"
    export ADB_WORKSPACE="$(readConfigItem .ResourceGroupName)$(readConfigItem .Databricks.WorkspaceName)"
    echo "ADB_WORKSPACE: $ADB_WORKSPACE"
    export ADB_TOKEN_KEYVAULT="$(readConfigItem .ResourceGroupName)$(readConfigItem .KeyVault.DatabricksKeyVaultName)"
    
    #TODO: Use custom template for log analytics init script
    #TODO: sync and clean up env variable to align with other steps
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
    echo "Start to set up ingestion function"
    #TODO: Modify to deploy python function and configure function
    # export PROC_FUNCTION_APP_NAME=$PREFIX"process"
    # export PROC_FUNCTION_NAME=StreamingProcessor
    # export PROC_PACKAGE_FOLDER=.
    # export PROC_PACKAGE_TARGET=AzureSQL    
    # export PROC_PACKAGE_NAME=$PROC_FUNCTION_NAME-$PROC_PACKAGE_TARGET.zip
    # export PROC_PACKAGE_PATH=$PROC_PACKAGE_FOLDER/$PROC_PACKAGE_NAME
    # export SQL_PROCEDURE_NAME="stp_WriteData$TABLE_SUFFIX"

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

# ---- END: CALL THE SCRIPT TO SETUP USED DATABASE AND STREAM PROCESSOR

echo "***** [T] Starting up TEST clients"
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
        #pip install -r "$scriptpath/requirements.txt"
        python "$scriptpath/cleanup_adx_all_db_records.py"
        python "$scriptpath/count_adx_all_db_records.py"

        echo "***** start to simulate data"
        # source ../simulator/run-generator-datalake.sh 
        # include the get storage secret info function code
        export AZURE_STORAGE_ACCOUNT="$(readConfigItem .ResourceGroupName)$(readConfigItem .Storage.LandingDatalakeName)"
        
        source ../components/azure-storage/get-storage-secret-info.sh
        echo "AZURE_STORAGE_ACCOUNT: $AZURE_STORAGE_ACCOUNT"
        landingkey=$(getStorageSecretInfo accesskey)
        echo "landingkey: $landingkey"

        echo "start to gen fake data"
        export scriptpath="./tools/fakedata-generator"
        pip install -r "$scriptpath/requirements.txt"
        container="$(readConfigItem .Storage.FileSystemName)"
        folder="$(readConfigItem .Storage.FileSystemNameRootFolder)"
        python "$scriptpath/fake_data_generator.py" -fc 1 -c 10 -i 1 -m 2 -ta $AZURE_STORAGE_ACCOUNT -tk $landingkey -tc $container -tf $folder 
    fi
echo

echo "***** [V] Starting deployment VERIFICATION"
    echo "Not implemented! Need to create verification script"
    WAITTIME="5m"
    #TODO: Need to modify current evaluation script
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
        # source ../streaming/databricks/runners/verify-azureadx.sh
    fi
echo

echo "***** Done"
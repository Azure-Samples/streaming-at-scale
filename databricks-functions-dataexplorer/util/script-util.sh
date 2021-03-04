#!/bin/bash
# [datalake-databricks-function-dataexplore]

# Strict mode, fail on any error
set -euo pipefail

# reads specific text-based item from the JSON config file
function readConfigItem() {
    # use jq to read a key
    local retVal=`jq "$1" $CONFIG_FILE_NAME`

    # test if remove all quotes or not
    if [ -z ${2+x} ]; then 
      retVal=`echo "$retVal" | tr -d '"'`
    fi

    # return retVal
    echo "$retVal"
}

# loop through parameters and print, for debugging
function printParameters() {
    arr=("$@")
    for i in "${arr[@]}";
      do
        echo "$i"
      done
}

# converts a list of parameters into a string for use with az cli
function parametersAsString() {
    retVal=""
    arr=("$@")
    for i in "${arr[@]}";
      do
        retVal="${retVal} ${i}"
      done
    echo $retVal
}

function combineSecretPair() {
    local -n secretMap_ref=$1
    secretPairs="["
    for K in "${!secretMap_ref[@]}"; 
    do 
        key=$K
        value=${secretMap_ref[$K]}
        secretPairs+="{\"key\":\"${key}\",\"value\":\"${value}\"},"
    done
    secretPairs+="]"
    

    SecretPairJson='{"secretPairs":'"$secretPairs"'}'

    keyvault_secret_parameters=("KeyVaultName=${AZURE_KEY_VAULT_NAME}")
    keyvault_secret_parameters+=("Secrets=${SecretPairJson}")
    
    echo "${keyvault_secret_parameters[@]}"
}

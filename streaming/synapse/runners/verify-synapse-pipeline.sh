#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

wait_for_completion="$1"
echo $wait_for_completion
SYNAPSE_SPARKPOOL="sasesssparkpool"
AVRO_TO_DELTA_PIPELINE_NAME="blob-avro-to-delta-synapse"
VERIFY_PIPELINE_NAME="verify-avro-to-delta"
DELTA_PIPELINE_PARAMETER_FILE="../streaming/synapse/pipelines/delta-pipeline-parameters.json"
TEMP_PIPELINE_PARAMETER_FILE="../streaming/synapse/pipelines/delta-pipeline-parameters.temp.json"
wait_for_run () {
    declare RUN_ID=$1
    echo $RUN_ID
    echo -n "Waiting for run ${RUN_ID} to finish..."
    while : ; do
        quoted_status=$(az synapse pipeline-run show --run-id $RUN_ID \
        --workspace-name $SYNAPSE_WORKSPACE \
        --query "status")
        
        status="${quoted_status:1:${#quoted_status}-2}" # Removes quotes around status
        echo "Pipe status is: ${status}"
        if [[ $status != "InProgress" && $status != "Queued" ]]; then
            echo "$status"
            break;
        else 
            echo -n .
            sleep 30
        fi
    done
    echo

    message=$(az synapse pipeline-run show --run-id $RUN_ID \
    --workspace-name $SYNAPSE_WORKSPACE \
    --query "message")
    echo "[$status] $message"

    if [ $status != "Succeeded" ]; then
        echo "Unsuccessful run"
    fi
}
BLOB_BASE_PATH="streamingatscale/capture/$eventHubsNamespace/$eventHubName"
tmp=$(mktemp)
jq --arg a "${BLOB_BASE_PATH}" '.folder_path = $a' $DELTA_PIPELINE_PARAMETER_FILE > "$tmp" && mv "$tmp" $TEMP_PIPELINE_PARAMETER_FILE
echo "Starting Avro to Delta Pipeline"
DELTA_TEMP_RUN_ID=$(az synapse pipeline create-run --workspace-name $SYNAPSE_WORKSPACE \
  --name $AVRO_TO_DELTA_PIPELINE_NAME \
  --parameters @"../streaming/synapse/pipelines/delta-pipeline-parameters.temp.json" \
  --query 'runId')

# The value of runId from the above query is a quoted string and doesn't work 
# when used as a parameter in az synapse pipeline-run show.
# Therefore we remove the quotes in the first and last index.  
DELTA_PIPELINE_RUN_ID="${DELTA_TEMP_RUN_ID:1:${#DELTA_TEMP_RUN_ID}-2}"
echo "Creating Synapse Avro to Delta Verification Notebook"
az synapse notebook create --workspace-name $SYNAPSE_WORKSPACE \
--name "verify-delta" \
--file @"../streaming/synapse/notebooks/verify-delta.ipynb" \
--spark-pool-name $SYNAPSE_SPARKPOOL

echo "Creating Synapse Avro to Delta Verification Pipeline"
az synapse pipeline create --workspace-name $SYNAPSE_WORKSPACE \
  --name $VERIFY_PIPELINE_NAME --file @"../streaming/synapse/pipelines/verify-delta.json"

TEMP_RUN_ID=$(az synapse pipeline create-run --workspace-name $SYNAPSE_WORKSPACE \
  --name $VERIFY_PIPELINE_NAME \
  --parameters @"../streaming/synapse/pipelines/verify-delta-parameters.json" \
  --query 'runId')

VERIFY_PIPELINE_RUN_ID="${TEMP_RUN_ID:1:${#TEMP_RUN_ID}-2}"

echo "starting Synapse pipeline for $VERIFY_PIPELINE_NAME" | tee -a log.txt

if "$wait_for_completion"; then
    # First, run blob-avro-to-delta-synapse to create delta table
    wait_for_run $DELTA_PIPELINE_RUN_ID

    # Verifies the table
    wait_for_run $VERIFY_PIPELINE_RUN_ID 

    echo "Downloading Verification Results"
    source ../streaming/synapse/runners/verify-download-result.sh
fi

#!/bin/bash

wait_for_completion="$1"
echo $wait_for_completion

echo "Creating Avro-to-Delta Pipeline"
DELTA_PIPELINE_RUN_ID=$(create_pipeline_run \
  $AVRO_TO_DELTA_PIPELINE_NAME \
  $AVRO_TO_DELTA_PIPELINE_FILE \
  $TEMP_PIPELINE_PARAMETER_FILE)

echo "Avro-to-Delta Pipeline Id: $DELTA_PIPELINE_RUN_ID"

echo "Creating Verify-Delta Pipeline"
VERIFY_PIPELINE_RUN_ID=$(create_pipeline_run \
  $VERIFY_PIPELINE_NAME \
  $VERIFY_PIPELINE_FILE \
  $VERIFY_PIPELINE_PARAMETER_FILE)
echo "Verify Delta Pipeline Id: $VERIFY_PIPELINE_RUN_ID"

if "$wait_for_completion"; then
    # First, run blob-avro-to-delta-synapse to create delta table
    wait_for_run $DELTA_PIPELINE_RUN_ID

    # Verifies the table
    wait_for_run $VERIFY_PIPELINE_RUN_ID 

    echo "Downloading Verification Results"
    source ../streaming/synapse/runners/verify-download-result.sh
fi

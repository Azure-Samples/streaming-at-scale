
echo "Creating Avro-to-Delta Pipeline"
DELTA_PIPELINE_RUN_ID=$(create_pipeline_run \
  $BLOB_TRIGGERED_PIPELINE_NAME \
  $AVRO_TO_DELTA_PIPELINE_FILE \
  $TEMP_PIPELINE_PARAMETER_FILE)

echo "Creating Trigger to Run Pipeline"
az synapse trigger create --workspace-name $SYNAPSE_WORKSPACE \
  --name $TRIGGER_NAME \
  --file @"$TRIGGER_FILE"

echo "Starting Trigger to Run Pipeline"
az synapse trigger start --workspace-name $SYNAPSE_WORKSPACE \
  --name $TRIGGER_NAME
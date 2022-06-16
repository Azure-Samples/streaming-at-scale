
echo "Creating Avro-to-Delta Pipeline"
PIPELINE_RUN_ID=$(create_pipeline_run \
  $AVRO_TO_DELTA_PIPELINE_NAME \
  $AVRO_TO_DELTA_PIPELINE_FILE \
  $TEMP_PIPELINE_PARAMETER_FILE)

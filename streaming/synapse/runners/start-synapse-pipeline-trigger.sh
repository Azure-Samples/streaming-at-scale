PIPELINE_NAME="blob-avro-to-delta-synapse"

TRIGGER_NAME="avro-to-delta-trigger"

echo "Starting Trigger to Run Pipeline"
az synapse trigger start --workspace-name $SYNAPSE_WORKSPACE \
  --name $TRIGGER_NAME
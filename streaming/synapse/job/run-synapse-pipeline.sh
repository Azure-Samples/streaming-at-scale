#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

workspace_name=$1
wait_for_completion="$2"
pipeline_name="$3"

wait_for_run () {
    declare run_id=$1
    echo -n "Waiting for run ${run_id} to finish..."
    while : ; do
        status=$(az synapse pipeline-run show --run-id $run_id --workspace-name $workspace_name --query "status")
        if [[ $status != "InProgress" && $status != "Queued" ]]; then
            echo "Paul: $status"
            break;
        else 
            echo -n .
            sleep 30
        fi
    done
    echo

    message=$(az synapse pipeline-run show --run-id $run_id --workspace-name $workspace_name --query "message")
    echo "[$status] $message"

    if [ $result_state != "Succeeded" ]; then
        echo "Unsuccessful run"
        exit 1
    fi
}

test () {
  echo "testing..."
}

echo "starting Synapse pipeline for $pipeline_name" | tee -a log.txt

run_id=$(az synapse pipeline create-run --workspace-name $workspace_name --name "$pipeline_name" \
  --parameters "{
  \"input_table_location\":\"/datalake/normalized/streaming_device\",
  \"test_output_path\": \"/test-ouptut/verify-delta/output.txt\",
  \"assert_events_per_second\": 900,
  \"assert_latency_milliseconds\": 15000,
  \"assert_duplicate_fraction\": -1,
  \"assert_out_of_sequence_fraction\": 0
}" --query "runId")

run_id="091c0920-4a3d-43ed-95f9-64706131def2"

if "$wait_for_completion"; then
    wait_for_run $run_id
fi
exit 0

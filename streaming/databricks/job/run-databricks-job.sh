#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

notebook_name="$1"
wait_for_completion="$2"
job_jq_command="$3"

wait_for_run () {
    # See here: https://docs.azuredatabricks.net/api/latest/jobs.html#jobsrunresultstate
    declare run_id=$1
    echo -n "Waiting for run ${run_id} to finish..."
    while : ; do
        run_info=$(databricks runs get --run-id $run_id)
        state=$(jq -r ".state.life_cycle_state" <<< "$run_info") 
        if [[ $state == "TERMINATED" || $state == "SKIPPED" || $state == "INTERNAL_ERROR" ]]; then
            echo " $state"
            break;
        else 
            echo -n .
            sleep 10
        fi
    done

    result_state=$(jq -r ".state.result_state" <<< "$run_info") 
    state_message=$(jq -r ".state.state_message" <<< "$run_info")
    echo "[$result_state] $state_message"

    if [ $result_state != "SUCCESS" ]; then
        echo "Unsuccessful run"
        exit 1
    fi
}

# It is recommended to run each streaming job on a dedicated cluster.

cluster_jq_command="$(cat <<JQ
  .name = "Streaming at scale job $notebook_name"
  | .notebook_task.notebook_path = "/Shared/streaming-at-scale/$notebook_name"
  | .new_cluster.node_type_id = "$DATABRICKS_NODETYPE"
  | .new_cluster.num_workers = $DATABRICKS_WORKERS
  | .timeout_seconds = $((REPORT_THROUGHPUT_MINUTES * 60))
JQ
)"

if [ -n "${DATABRICKS_CLUSTER:-}" ]; then
  echo "Using existing cluster $DATABRICKS_CLUSTER (use for development only!)"
  cluster_jq_command="$cluster_jq_command | del(.new_cluster) | .existing_cluster_id = \"$DATABRICKS_CLUSTER\""
fi

echo "starting Databricks notebook job for $notebook_name" | tee -a log.txt

job_def=$(cat ../streaming/databricks/job/job-config.json | jq "$cluster_jq_command" | jq "$job_jq_command")

job=$(databricks jobs create --json "$job_def")
job_id=$(echo $job | jq .job_id)

run=$(databricks jobs run-now --job-id $job_id)

# Echo job web page URL to task output to facilitate debugging
run_id=$(echo $run | jq .run_id)
databricks runs get --run-id "$run_id" | jq -r .run_page_url | tee -a log.txt

if "$wait_for_completion"; then
  wait_for_run "$run_id"
fi

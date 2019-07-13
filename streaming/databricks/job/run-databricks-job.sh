#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

notebook_name="$1"
job_jq_command="$2"

# It is recommended to run each streaming job on a dedicated cluster.

cluster_jq_command="$(cat <<JQ
  .name = "Streaming at scale job $notebook_name"
  | .notebook_task.notebook_path = "/Shared/streaming-at-scale/$notebook_name"
  | .new_cluster.node_type_id = "$DATABRICKS_NODETYPE"
  | .new_cluster.num_workers = $DATABRICKS_WORKERS
JQ
)"

echo "starting Databricks notebook job for $notebook_name" | tee -a log.txt

job_def=$(cat ../streaming/databricks/job/job-config.json | jq "$cluster_jq_command" | jq "$job_jq_command")

job=$(databricks jobs create --json "$job_def")
job_id=$(echo $job | jq .job_id)

run=$(databricks jobs run-now --job-id $job_id)

# Echo job web page URL to task output to facilitate debugging
run_id=$(echo $run | jq .run_id)
databricks runs get --run-id "$run_id" | jq -r .run_page_url | tee -a log.txt


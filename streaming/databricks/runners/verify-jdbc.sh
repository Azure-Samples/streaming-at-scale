#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "jdbc-pass" --string-value "$JDBC_PASS"

source ../streaming/databricks/job/run-databricks-job.sh verify-jdbc true "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "$JDBC_DRIVER" } } ]
  | .notebook_task.base_parameters."test-output-path" = "$DATABRICKS_TESTOUTPUTPATH"
  | .notebook_task.base_parameters."jdbc-url" = "$JDBC_URL"
  | .notebook_task.base_parameters."jdbc-user" = "$JDBC_USER"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
  | .notebook_task.base_parameters."assert-duplicate-fraction" = "$ALLOW_DUPLICATE_FRACTION"
  | .notebook_task.base_parameters."assert-outofsequence-fraction" = "$ALLOW_OUTOFSEQUENCE_FRACTION"
JQ
)"

source ../streaming/databricks/runners/verify-download-result.sh

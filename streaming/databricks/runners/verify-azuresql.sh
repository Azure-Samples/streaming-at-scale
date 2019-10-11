#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

echo 'writing Databricks secrets'
databricks secrets put --scope "MAIN" --key "azuresql-pass" --string-value "$SQL_ADMIN_PASS"

source ../streaming/databricks/job/run-databricks-job.sh verify-azuresql true "$(cat <<JQ
  .libraries += [ { "maven": { "coordinates": "com.microsoft.azure:azure-sqldb-spark:1.0.2" } } ]
  | .notebook_task.base_parameters."azuresql-servername" = "$SQL_SERVER_NAME"
  | .notebook_task.base_parameters."azuresql-finaltable" = "$SQL_TABLE_NAME"
  | .notebook_task.base_parameters."assert-events-per-second" = "$(($TESTTYPE * 900))"
  | .notebook_task.base_parameters."assert-duplicate-fraction" = "$ALLOW_DUPLICATE_FRACTION"
  | .notebook_task.base_parameters."assert-outofsequence-fraction" = "$ALLOW_OUTOFSEQUENCE_FRACTION"
JQ
)"

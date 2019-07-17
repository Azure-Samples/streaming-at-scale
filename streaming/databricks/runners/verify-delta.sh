#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

source ../streaming/databricks/runners/verify-common.sh

source ../streaming/databricks/job/run-databricks-job.sh verify-delta true "$(cat <<JQ
  .notebook_task.base_parameters."delta-table" = "events_$PREFIX"
JQ
)"

#!/bin/sh

# Build a job spec to run multiple integration tests.
# Return JSON format to be used in the `matrix' field of an Azure DevOps Pipelines  job
# See: https://docs.microsoft.com/en-us/azure/devops/pipelines/process/phases#multi-configuration

set -euo pipefail

jobs_spec="{}"

function generate_test_jobs {
  testDir=$1; shift
  uniquePrefix=$1; shift
  steps=$1; shift
  throughputMinutes=$1; shift
  arg_t_values=$1; shift
  extra_arg_name=${1:-}; test -n "$extra_arg_name" && shift
  extra_arg_values=${1:-x}

    subtestNumber=0
    for extra_arg_value in $extra_arg_values; do
      let "subtestNumber=$subtestNumber+1"
      extra_arg=""
      test -n "$extra_arg_name" && extra_arg="-$extra_arg_name $extra_arg_value"
      for arg_t_value in $arg_t_values; do
        unique_jobname="$uniquePrefix$subtestNumber$arg_t_value"
        jobs_spec=$(jq ". + {$unique_jobname: {TestDir: \"$testDir\", REPORT_THROUGHPUT_MINUTES: $throughputMinutes, TestArgs: \"-l ${LOCATION:-eastus} -s $steps -t $arg_t_value $extra_arg\"}}" <<< "$jobs_spec")
      done
    done
}

#                  Folder                                        prefix  steps   min  throughput extra_arg
#                  -----------------------------                 ------  ------- ---  ---------- --------------------------------------------
generate_test_jobs eventhubs-databricks-azuresql                   eda1  CIDPTMV  20  "1 10"     "k" "rowstore"
generate_test_jobs eventhubs-databricks-azuresql                   eda2  CIDPTMV  20  "1"        "k" "columnstore"
generate_test_jobs eventhubs-databricks-cosmosdb                   edc1  CIDPTMV  20  "1 10"
generate_test_jobs eventhubs-databricks-delta                      edd1  CIPTMV   20  "1 10"
generate_test_jobs eventhubs-dataexplorer                          ed1   CIPTMV   30  "1 10"
generate_test_jobs eventhubs-functions-azuresql                    efa1  CIDPTMV  10  "1 10"     "k" "rowstore"
generate_test_jobs eventhubs-functions-azuresql                    efa2  CIDPTMV  10  "1"        "k" "columnstore rowstore-inmemory columnstore-inmemory"
generate_test_jobs eventhubs-functions-cosmosdb                    efc1  CIDPTMV  10  "1 10"     "f" "Test0"
generate_test_jobs eventhubs-functions-cosmosdb                    efc2  CIDPTMV  10  "1"        "f" "Test1"
generate_test_jobs eventhubs-streamanalytics-azuresql              esa1  CIDPTMV  10  "1 10"     "k" "rowstore"
generate_test_jobs eventhubs-streamanalytics-azuresql              esa2  CIDPTMV  10  "1"        "k" "columnstore"
generate_test_jobs eventhubs-streamanalytics-cosmosdb              esc1  CIDPTMV  10  "1 10"
generate_test_jobs eventhubs-streamanalytics-eventhubs             ese1  CIPTMV   10  "1 10"     "a" "simple"
generate_test_jobs eventhubs-streamanalytics-eventhubs             ese2  CIPTMV   10  "1"        "a" "anomalydetection"
generate_test_jobs eventhubskafka-databricks-cosmosdb              kdc1  CIDPTMV  20  "1 10"
generate_test_jobs hdinsightkafka-databricks-sqldw                 hdw1  CIDPTMV  20  "1 10"     "k" "columnstore"
generate_test_jobs hdinsightkafka-databricks-sqldw                 hdw2  CIDPTMV  20  "1"        "k" "rowstore"

echo $jobs_spec

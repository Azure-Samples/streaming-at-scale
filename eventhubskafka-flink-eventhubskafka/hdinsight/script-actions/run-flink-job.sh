#!/bin/bash

set -x
set -euo pipefail

source /opt/flink/HDInsightUtilities.sh 

# Only run on first data node (to run only once in entire cluster)
if [ $(test_is_first_datanode) == 0 ] ; then
  exit 0
fi

tmpdir=$(mktemp -d)
jobjar="$tmpdir/job.jar"
hdfs dfs -copyToLocal "$1" "$jobjar"

shift

cd /opt/flink/flink
./bin/flink run $jobjar "$@"

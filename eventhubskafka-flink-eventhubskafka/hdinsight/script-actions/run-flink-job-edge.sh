#!/bin/bash

set -x
set -euo pipefail

source /opt/flink/HDInsightUtilities.sh 

function test_is_edge_node
{
    shorthostname=`hostname -s`
    edgenodename='flinkhdiazedgenode'
    if [[ $shorthostname == $firstdatanode ]]; then
        echo 1;
    else
        echo 0;
    fi
}

# Only run on first data node (to run only once in entire cluster)
if [ $(test_is_edge_node) == 0 ] ; then
  echo  "not edge node stopping script"
  exit 0
fi

echo "running flink setup on edge node"

tmpdir=$(mktemp -d)
jobjar="$tmpdir/job.jar"
hdfs dfs -copyToLocal "$1" "$jobjar"

shift

flink_master=$(yarn app -list -appTypes "Apache Flink" | sed -rn 's!.*http://(.*)!\1!p' | head -1)

if [ -z "$flink_master" ]; then
  echo "Couldn't find Flink JobManager in YARN. Is Flink running?" >&2
  exit 1
fi

cd /opt/flink/flink
./bin/flink run --jobmanager "$flink_master" --detached $jobjar "$@"

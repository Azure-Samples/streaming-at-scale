#!/bin/bash

set -euo pipefail

flink_version=$1
flink_scala_version=$2

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
# Import the helper method module.
# See https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-script-actions-linux#helpermethods
mkdir -p /opt/flink
curl -sfL -o /opt/flink/HDInsightUtilities.sh https://hdiconfigactions.blob.core.windows.net/linuxconfigactionmodulev01/HDInsightUtilities-v01.sh 
source /opt/flink/HDInsightUtilities.sh 

# Stop if Flink is already running
flink_master=$(yarn app -list -appTypes "Apache Flink" | sed -rn 's!.*http://(.*)!\1!p' | head -1)
if [ -n "$flink_master" ]; then
  echo "Flink is already running" >&2
  exit 0
fi

# Download Flink runtime
cd /opt/flink
curl -sfL -o flink.tgz "https://archive.apache.org/dist/flink/flink-$flink_version/flink-$flink_version-bin-scala_$flink_scala_version.tgz"
tar zxvf flink.tgz
rm -f flink
ln -s flink-$flink_version flink
cd flink

# Start Flink as YARN application
export HADOOP_CLASSPATH=$(hadoop classpath)
./bin/yarn-session.sh --jobManagerMemory 1024m --taskManagerMemory 4096m --detached --name Flink --applicationType "Apache Flink"

# Check Flink has started
flink_master=$(yarn app -list -appTypes "Apache Flink" | sed -rn 's!.*http://(.*)!\1!p' | head -1)
if [ -z "$flink_master" ]; then
  echo "Flink failed to start" >&2
  exit 1
fi

# Write Flink master host and port to HDFS (Azure Storage), so the caller can use them to set up an SSH tunnel
echo "$flink_master" | hdfs dfs -put - /apps/flink/flink_master.txt

#!/bin/bash

set -euo pipefail

# Import the helper method module.
# See https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-script-actions-linux#helpermethods
mkdir -p /opt/flink
curl -sfL -o /opt/flink/HDInsightUtilities.sh https://hdiconfigactions.blob.core.windows.net/linuxconfigactionmodulev01/HDInsightUtilities-v01.sh 
source /opt/flink/HDInsightUtilities.sh 

# Only run on first data node (to run only once in entire cluster)
if [ $(test_is_first_datanode) == 0 ] ; then
  exit 0
fi

flink_version=1.9.1
scala_version=2.11

cd /opt/flink
curl -sfL -o flink.tgz "https://archive.apache.org/dist/flink/flink-$flink_version/flink-$flink_version-bin-scala_$scala_version.tgz"
tar zxvf flink.tgz
rm -f flink
ln -s flink-$flink_version flink
cd flink
export HADOOP_CLASSPATH=$(hadoop classpath)
./bin/yarn-session.sh --jobManagerMemory 1024m --taskManagerMemory 4096m --detached --name Flink

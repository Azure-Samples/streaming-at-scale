#!/bin/bash

set -euo pipefail

# Import the helper method module.
# See https://docs.microsoft.com/en-us/azure/hdinsight/hdinsight-hadoop-script-actions-linux#helpermethods
wget -O /tmp/HDInsightUtilities-v01.sh -q https://hdiconfigactions.blob.core.windows.net/linuxconfigactionmodulev01/HDInsightUtilities-v01.sh 
source /tmp/HDInsightUtilities-v01.sh 
rm -f /tmp/HDInsightUtilities-v01.sh

# Only run on first data node (to run only once in entire cluster)
if [ $(test_is_first_datanode) == 0 ] ; then
  return
fi

flink_version=1.9.1

curl -sfL -o flink.tgz "https://www-us.apache.org/dist/flink/flink-1.9.1/flink-1.9.1-bin-scala_2.11.tgz"
tar zxvf flink.tgz
cd flink-$flink_version
export HADOOP_CLASSPATH=$(hadoop classpath)
./bin/yarn-session.sh -jm 1024m -tm 4096m &

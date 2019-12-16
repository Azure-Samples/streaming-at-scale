source ../components/azure-monitor/create-log-analytics.sh
source ../components/azure-hdinsight/create-hdinsight-hadoop.sh

pushd ../components/apache-flink > /dev/null
   source hdinsight/provision-hdinsight-flink-cluster.sh
   source hdinsight/run-flink-job.sh
popd > /dev/null

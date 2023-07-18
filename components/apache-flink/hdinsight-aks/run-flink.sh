source ../components/azure-monitor/create-log-analytics.sh
source ../components/azure-hdinsight/create-hdinsight-aks-flink.sh

pushd ../components/apache-flink > /dev/null
   source hdinsight-aks/run-flink-job.sh
popd > /dev/null

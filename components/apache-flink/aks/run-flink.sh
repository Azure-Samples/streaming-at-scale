# Create service principal for AKS.
# Run as early as possible in script, as principal takes time to become available for RBAC operations.
source ../components/azure-common/create-service-principal.sh

source ../components/azure-monitor/create-log-analytics.sh
source ../components/azure-monitor/create-application-insights.sh

pushd ../components/apache-flink/kubernetes/ > /dev/null
  source provision-aks-flink-cluster.sh
popd > /dev/null

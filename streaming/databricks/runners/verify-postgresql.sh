#!/bin/bash

# Strict mode, fail on any error
set -euo pipefail

echo "retrieving storage account key"
server_fqdn=$(az postgres server show -g $RESOURCE_GROUP -n $POSTGRESQL_SERVER_NAME --query fullyQualifiedDomainName -o tsv)
JDBC_URL="jdbc:postgresql://$server_fqdn/$POSTGRESQL_DATABASE_NAME"
JDBC_USER="serveradmin@$POSTGRESQL_SERVER_NAME"
JDBC_PASS="$POSTGRESQL_ADMIN_PASS"
JDBC_DRIVER="org.postgresql:postgresql:42.2.8.jre7"

source ../streaming/databricks/runners/verify-jdbc.sh

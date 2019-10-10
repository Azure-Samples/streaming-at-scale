// Databricks notebook source
dbutils.widgets.text("dataexplorer-cluster", "https://MYCLUSTER.northeurope.kusto.windows.net")
dbutils.widgets.text("dataexplorer-database", "streaming")
dbutils.widgets.text("dataexplorer-query", "EventTable")
dbutils.widgets.text("dataexplorer-client-id", "MYCLIENTID")
dbutils.widgets.text("dataexplorer-storage-account", "MYSTORAGE")
dbutils.widgets.text("dataexplorer-storage-container", "dataexplorer")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")
dbutils.widgets.text("assert-duplicate-fraction", "0", "Assert max proportion of duplicate events")

// COMMAND ----------

import com.microsoft.kusto.spark.datasource.KustoSourceOptions
import com.microsoft.kusto.spark.sql.extension.SparkExtension._
import org.apache.spark.SparkConf
import org.apache.spark.sql._

val cluster = dbutils.widgets.get("dataexplorer-cluster")
val database = dbutils.widgets.get("dataexplorer-database")
val query = dbutils.widgets.get("dataexplorer-query")
val conf: Map[String, String] = Map(
  KustoSourceOptions.KUSTO_AAD_CLIENT_ID -> dbutils.widgets.get("dataexplorer-client-id"),
  KustoSourceOptions.KUSTO_AAD_CLIENT_PASSWORD -> dbutils.secrets.get(scope = "MAIN", key = "dataexplorer-client-password"),
  KustoSourceOptions.KUSTO_BLOB_STORAGE_ACCOUNT_NAME -> dbutils.widgets.get("dataexplorer-storage-account"),
  KustoSourceOptions.KUSTO_BLOB_STORAGE_ACCOUNT_KEY -> dbutils.secrets.get(scope = "MAIN", key = "dataexplorer-storage-key"),
  KustoSourceOptions.KUSTO_BLOB_CONTAINER -> dbutils.widgets.get("dataexplorer-storage-container")
)
val data = spark
  .read
  .kusto(cluster, database, query, conf)

// COMMAND ----------

import java.util.UUID.randomUUID

val tempTable = "tempresult_" + randomUUID().toString.replace("-","_")

data
  .withColumn("enqueuedAt", $"createdAt")
  .withColumn("storedAt", $"createdAt")
  .createOrReplaceGlobalTempView(tempTable)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempTable),
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> dbutils.widgets.get("assert-latency-milliseconds"),
    "assert-duplicate-fraction" -> dbutils.widgets.get("assert-duplicate-fraction")
))

// Databricks notebook source
dbutils.widgets.text("storage-path", "", "WASB URL to data storage container")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")

// COMMAND ----------

import java.util.UUID.randomUUID
val tempTable = "temptable_" + randomUUID().toString.replace("-","_")
val storagePath = dbutils.widgets.get("storage-path")

// Create unmanaged/external table
spark.sql(s"CREATE TABLE `$tempTable` USING parquet LOCATION '$storagePath'")

// Discover table partitions in storage.
// Requires spark.hadoop.fs.azure.account.key to be set in cluster spark configuration
spark.sql(s"MSCK REPAIR TABLE `$tempTable`")

// COMMAND ----------

val tempView = "tempview_" + randomUUID().toString.replace("-","_")

table(tempTable)
  .withColumn("storedAt", $"createdAt_datetime")
  .withColumnRenamed("timestamp", "enqueuedAt")
  .withColumnRenamed("eventId_string", "eventId")
  .createOrReplaceGlobalTempView(tempView)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempView),
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> "0" // As we use event timestamp as stored timestamp, measured latency should be 0
))

// COMMAND ----------

sql(s"DROP TABLE `$tempTable`")

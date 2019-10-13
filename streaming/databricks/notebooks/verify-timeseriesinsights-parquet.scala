// Databricks notebook source
dbutils.widgets.text("test-output-path", "dbfs:/test-output/test-output.txt", "DBFS location to store assertion results")
dbutils.widgets.text("storage-path", "", "WASB URL to data storage container")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-duplicate-fraction", "0", "Assert max proportion of duplicate events")
dbutils.widgets.text("assert-outofsequence-fraction", "0", "Assert max proportion of out-of-sequence events")

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
  // TSI ingestion is configured to use 'createdAt' field as timestamp.
  .withColumn("storedAt", $"timestamp")
  .withColumnRenamed("timestamp", "enqueuedAt")
  .withColumnRenamed("deviceId_string", "deviceId")
  .withColumnRenamed("eventId_string", "eventId")
  .withColumnRenamed("deviceSequenceNumber_double", "deviceSequenceNumber")
  .createOrReplaceGlobalTempView(tempView)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "test-output-path" -> dbutils.widgets.get("test-output-path"),
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempView),
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> "0", // As we use event timestamp as stored timestamp, measured latency should be 0
    "assert-duplicate-fraction" -> dbutils.widgets.get("assert-duplicate-fraction"),
    "assert-outofsequence-fraction" -> dbutils.widgets.get("assert-outofsequence-fraction")
))

// COMMAND ----------

sql(s"DROP TABLE `$tempTable`")

// Databricks notebook source
dbutils.widgets.text("test-output-path", "dbfs:/test-output/test-output.txt", "DBFS location to store assertion results")
dbutils.widgets.text("jdbc-url", "")
dbutils.widgets.text("jdbc-user", "serveradmin")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")
dbutils.widgets.text("assert-duplicate-fraction", "0", "Assert max proportion of duplicate events")
dbutils.widgets.text("assert-outofsequence-fraction", "0", "Assert max proportion of out-of-sequence events")

// COMMAND ----------
val jdbcUrl = dbutils.widgets.get("jdbc-url")

import java.util.Properties
val connectionProperties = new Properties()
connectionProperties.put("user", dbutils.widgets.get("jdbc-user"))
connectionProperties.put("password", dbutils.secrets.get(scope = "MAIN", key = "jdbc-pass"))
connectionProperties.setProperty("ssl", "true")


val data = spark
  .read
  .jdbc(jdbcUrl, "(SELECT * FROM rawdata ORDER BY createdAt LIMIT 60 * 1000 * 20) AS subset", connectionProperties)

// COMMAND ----------
import java.util.UUID.randomUUID

val tempTable = "tempresult_" + randomUUID().toString.replace("-","_")

data
  .createOrReplaceGlobalTempView(tempTable)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "test-output-path" -> dbutils.widgets.get("test-output-path"),
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempTable),
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> dbutils.widgets.get("assert-latency-milliseconds"),
    "assert-duplicate-fraction" -> dbutils.widgets.get("assert-duplicate-fraction"),
    "assert-outofsequence-fraction" -> dbutils.widgets.get("assert-outofsequence-fraction")
))

// Databricks notebook source
dbutils.widgets.text("sqldw-servername", "")
dbutils.widgets.text("sqldw-user", "serveradmin")
dbutils.widgets.text("sqldw-tempstorage-account", "")
dbutils.widgets.text("sqldw-tempstorage-container", "sqldw")
dbutils.widgets.text("sqldw-table", "rawdata_cs")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")

// COMMAND ----------
val tempStorageAccount = dbutils.widgets.get("sqldw-tempstorage-account")
val tempStorageContainer = dbutils.widgets.get("sqldw-tempstorage-container")
val serverName = dbutils.widgets.get("sqldw-servername")
val jdbcUrl = s"jdbc:sqlserver://$serverName.database.windows.net;database=streaming"
spark.conf.set(
  s"fs.azure.account.key.$tempStorageAccount.blob.core.windows.net",
  dbutils.secrets.get(scope = "MAIN", key = "storage-account-key"))

val data = spark
  .read
  .format("com.databricks.spark.sqldw")
  .option("url", jdbcUrl)
  .option("user", dbutils.widgets.get("sqldw-user"))
  .option("password", dbutils.secrets.get(scope = "MAIN", key = "sqldw-pass"))
  .option("tempDir", s"wasbs://$tempStorageContainer@$tempStorageAccount.blob.core.windows.net/")
  .option("forwardSparkAzureStorageCredentials", "true")
  .option("maxStrLength", "4000")
  .option("dbTable", dbutils.widgets.get("sqldw-table"))
  .load()

// COMMAND ----------
import java.util.UUID.randomUUID

val tempTable = "tempresult_" + randomUUID().toString.replace("-","_")

data
  .createOrReplaceGlobalTempView(tempTable)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempTable),
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> dbutils.widgets.get("assert-latency-milliseconds")
))

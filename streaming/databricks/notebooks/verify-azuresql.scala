// Databricks notebook source
dbutils.widgets.text("verify-settings", "{}", "Verification job settings")
dbutils.widgets.text("azuresql-servername", "servername")
dbutils.widgets.text("azuresql-finaltable", "[dbo].[rawdata]")

// COMMAND ----------
import com.microsoft.azure.sqldb.spark.bulkcopy.BulkCopyMetadata
import com.microsoft.azure.sqldb.spark.config.Config
import com.microsoft.azure.sqldb.spark.connect._

val dbConfig = Config(Map(
  "url"               -> (dbutils.widgets.get("azuresql-servername") + ".database.windows.net"),
  "user"              -> "serveradmin",
  "password"          -> dbutils.secrets.get(scope = "MAIN", key = "azuresql-pass"),
  "databaseName"      -> "streaming",
  "dbTable"           -> dbutils.widgets.get("azuresql-finaltable")
))

val data = spark
  .read
  .sqlDB(dbConfig)

// COMMAND ----------
import java.util.UUID.randomUUID

val tempTable = "tempresult_" + randomUUID().toString.replace("-","_")

data
  .createOrReplaceGlobalTempView(tempTable)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "verify-settings" -> dbutils.widgets.get("verify-settings"),
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempTable)
))

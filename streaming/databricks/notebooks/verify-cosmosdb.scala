// Databricks notebook source
dbutils.widgets.text("cosmosdb-endpoint", "https://MYACCOUNT.documents.azure.com", "Cosmos DB endpoint")
dbutils.widgets.text("cosmosdb-database", "streaming", "Cosmos DB database")
dbutils.widgets.text("cosmosdb-collection", "rawdata", "Cosmos DB collection")

// COMMAND ----------

import com.microsoft.azure.cosmosdb.spark.schema._
import com.microsoft.azure.cosmosdb.spark.config.Config
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import java.util.UUID.randomUUID

// Configure the connection to your collection in Cosmos DB.
// Please refer to https://github.com/Azure/azure-cosmosdb-spark/wiki/Configuration-references
// for the description of the available configurations.
val cosmosDbConfig = Config(Map(
  "Endpoint" -> dbutils.widgets.get("cosmosdb-endpoint"),
  "Masterkey" -> dbutils.secrets.get(scope = "MAIN", key = "cosmosdb-write-master-key"),
  "Database" -> dbutils.widgets.get("cosmosdb-database"),
  "Collection" -> dbutils.widgets.get("cosmosdb-collection")
))

val schema = StructType(
  StructField("eventId", StringType) ::
  StructField("complexData", StructType((1 to 22).map(i => StructField(s"moreData$i", DoubleType)))) ::
  StructField("value", StringType) ::
  StructField("type", StringType) ::
  StructField("deviceId", StringType) ::
  StructField("createdAt", StringType) ::
  StructField("enqueuedAt", StringType) ::
  StructField("processedAt", StringType) ::
  StructField("_ts", LongType) ::
  Nil)

val data = spark
  .read
  .schema(schema)
  .cosmosDB(cosmosDbConfig)

// COMMAND ----------

import java.util.UUID.randomUUID

val cosmosDbDateFormat = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSX")
// Spark's unix_timestamp only converts down to the second, this UDF converts down to milliseconds.
val cosmos_db_date_to_timestamp = udf((s: String) => new java.sql.Timestamp(cosmosDbDateFormat.parse(s).getTime))

val tempTable = "tempresult_" + randomUUID().toString.replace("-","_")

data
  .withColumn("createdAt", cosmos_db_date_to_timestamp($"createdAt"))
  .withColumn("enqueuedAt", cosmos_db_date_to_timestamp($"enqueuedAt"))
  .withColumn("processedAt", cosmos_db_date_to_timestamp($"processedAt"))
  .withColumn("storedAt", $"_ts".cast("timestamp"))
  .drop("_ts")
  .createOrReplaceGlobalTempView(tempTable)

// COMMAND ----------

dbutils.notebook.run("verify-common", 60, Map(
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempTable)
))

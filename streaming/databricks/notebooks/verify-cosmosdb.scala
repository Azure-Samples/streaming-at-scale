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

import java.sql.Timestamp
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter.ISO_DATE_TIME
import java.util.UUID.randomUUID

// Spark's unix_timestamp only converts down to the second, this UDF converts down to milliseconds
// and supports variable numbers of sub-second decimals.
val iso_datetime_to_ts = udf((s: String) => Timestamp.from(OffsetDateTime.parse(s, ISO_DATE_TIME).toInstant))

val tempTable = "tempresult_" + randomUUID().toString.replace("-","_")

data
  .withColumn("createdAt", iso_datetime_to_ts($"createdAt"))
  .withColumn("enqueuedAt", iso_datetime_to_ts($"enqueuedAt"))
  .withColumn("processedAt", iso_datetime_to_ts($"processedAt"))
  .withColumn("storedAt", $"_ts".cast("timestamp"))
  .drop("_ts")
  .createOrReplaceGlobalTempView(tempTable)

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "input-table" -> (spark.conf.get("spark.sql.globalTempDatabase") + "." + tempTable)
))

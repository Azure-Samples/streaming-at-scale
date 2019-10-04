// Databricks notebook source
dbutils.widgets.text("kafka-servers", "")
dbutils.widgets.text("kafka-topics", "streaming")
dbutils.widgets.text("sqldw-servername", "")
dbutils.widgets.text("sqldw-user", "serveradmin")
dbutils.widgets.text("sqldw-tempstorage-account", "")
dbutils.widgets.text("sqldw-tempstorage-container", "sqldw")
dbutils.widgets.text("sqldw-table", "rawdata_cs")

// COMMAND ----------

val data = spark.readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", dbutils.widgets.get("kafka-servers"))
  .option("subscribe", dbutils.widgets.get("kafka-topics"))
  .option("startingOffsets", "earliest")
  .load()

// COMMAND ----------

import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import java.time.Instant
import java.sql.Timestamp

val schema = StructType(
  StructField("eventId", StringType) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType)))) ::
  StructField("value", DoubleType) ::
  StructField("type", StringType) ::
  StructField("deviceId", StringType) ::
  StructField("createdAt", TimestampType) :: Nil)

val dataToWrite = data
  .select(from_json(decode($"value", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"timestamp".as("enqueuedAt"))
  .withColumn("ComplexData", to_json($"ComplexData"))
  .withColumn("ProcessedAt", lit(Timestamp.from(Instant.now)))
  .withColumn("StoredAt", current_timestamp)
  .select('eventId.as("EventId"), 'Type, 'DeviceId, 'CreatedAt, 'Value, 'ComplexData, 'EnqueuedAt, 'ProcessedAt, 'StoredAt)

// COMMAND ----------

val tempStorageAccount = dbutils.widgets.get("sqldw-tempstorage-account")
val tempStorageContainer = dbutils.widgets.get("sqldw-tempstorage-container")
val serverName = dbutils.widgets.get("sqldw-servername")
val jdbcUrl = s"jdbc:sqlserver://$serverName.database.windows.net;database=streaming"
spark.conf.set(
  s"fs.azure.account.key.$tempStorageAccount.blob.core.windows.net",
  dbutils.secrets.get(scope = "MAIN", key = "storage-account-key"))

dataToWrite.writeStream
  .format("com.databricks.spark.sqldw")
  .option("url", jdbcUrl)
  .option("user", dbutils.widgets.get("sqldw-user"))
  .option("password", dbutils.secrets.get(scope = "MAIN", key = "sqldw-pass"))
  .option("tempDir", s"wasbs://$tempStorageContainer@$tempStorageAccount.blob.core.windows.net/")
  .option("forwardSparkAzureStorageCredentials", "true")
  .option("maxStrLength", "4000")
  .option("dbTable", dbutils.widgets.get("sqldw-table"))
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/streaming-sqldw")
  .start()

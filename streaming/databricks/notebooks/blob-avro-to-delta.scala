// Databricks notebook source
dbutils.widgets.text("storage-account", "ADLSGEN2ACCOUNTNAME", "ADLS Gen2 storage account name")
dbutils.widgets.text("notification-queue", "", "Event grid notification storage queue (if empty, uses directory listing - slower)")
dbutils.widgets.text("delta-table", "streaming_events", "Delta table to store events (will be dropped if it exists)")

// COMMAND ----------

import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._

val gen2account = dbutils.widgets.get("storage-account")
val storageAccountKey = dbutils.secrets.get(scope = "MAIN", key = "storage-account-key")
spark.conf.set(s"fs.azure.account.key.$gen2account.dfs.core.windows.net", storageAccountKey)

// The AVRO data has additional fields, here we declare only the ones we're interested in
var schema = StructType(
  StructField("EnqueuedTimeUtc",StringType,true) ::
  StructField("Body",BinaryType,true) ::
  Nil)

val bodySchema = StructType(
  StructField("eventId", StringType, false) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType, false)))) ::
  StructField("value", StringType, false) ::
  StructField("type", StringType, false) ::
  StructField("deviceId", StringType, false) ::
  StructField("deviceSequenceNumber", LongType, false) ::
  StructField("createdAt", TimestampType, false) ::
  Nil)

val notificationQueueName = dbutils.widgets.get("notification-queue").trim

var cloudFilesOptions = scala.collection.mutable.Map[String, String]()
if (!notificationQueueName.isEmpty) {
  val connectionString = 
  cloudFilesOptions += (
    "cloudFiles.queueName" -> notificationQueueName,
    "cloudFiles.connectionString"
      -> s"DefaultEndpointsProtocol=https;AccountName=$gen2account;AccountKey=$storageAccountKey;EndpointSuffix=core.windows.net",
    "cloudFiles.useNotifications" -> "true"
  )
}

val streamData = spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "avro")
  .option("recursiveFileLookup", "true")
  .options(cloudFilesOptions)
  .schema(schema)
  .load(s"abfss://streamingatscale@$gen2account.dfs.core.windows.net/capture")

// COMMAND ----------

sql("DROP TABLE IF EXISTS `" + dbutils.widgets.get("delta-table") + "`")

// COMMAND ----------

// You can also use a path instead of a table, see https://docs.azuredatabricks.net/delta/delta-streaming.html#append-mode
streamData
  .withColumn("storedAt", current_timestamp)
  .withColumn("enqueuedAt", to_timestamp('EnqueuedTimeUtc, "M/d/y h:mm:ss a"))
  .withColumn("Body", from_json(decode('Body, "UTF-8"), bodySchema))
  .select(col("Body.*"), 'storedAt, 'enqueuedAt)
  .writeStream
  .outputMode("append")
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/blob-avro-to-delta/" + dbutils.widgets.get("delta-table"))
  .format("delta")
  .option("path", s"abfss://streamingatscale@$gen2account.dfs.core.windows.net/" + dbutils.widgets.get("delta-table"))
  .table(dbutils.widgets.get("delta-table"))

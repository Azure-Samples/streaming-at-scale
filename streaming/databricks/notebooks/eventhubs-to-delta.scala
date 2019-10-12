// Databricks notebook source
dbutils.widgets.text("eventhub-consumergroup", "delta", "Event Hubs consumer group")
dbutils.widgets.text("eventhub-maxEventsPerTrigger", "1000", "Event Hubs max events per trigger")
dbutils.widgets.text("storage-account", "ADLSGEN2ACCOUNTNAME", "ADLS Gen2 storage account name")
dbutils.widgets.text("delta-table", "streaming_events", "Delta table to store events (will be dropped if it exists)")

// COMMAND ----------

import org.apache.spark.eventhubs.{ EventHubsConf, EventPosition }

val eventHubsConf = EventHubsConf(dbutils.secrets.get(scope = "MAIN", key = "event-hubs-read-connection-string"))
  .setConsumerGroup(dbutils.widgets.get("eventhub-consumergroup"))
  .setStartingPosition(EventPosition.fromStartOfStream)
  .setMaxEventsPerTrigger(dbutils.widgets.get("eventhub-maxEventsPerTrigger").toLong)

val eventhubs = spark.readStream
  .format("eventhubs")
  .options(eventHubsConf.toMap)
  .load()

// COMMAND ----------

import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import java.time.Instant
import java.sql.Timestamp

val schema = StructType(
  StructField("eventId", StringType, false) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType, false)))) ::
  StructField("value", StringType, false) ::
  StructField("type", StringType, false) ::
  StructField("deviceId", StringType, false) ::
  StructField("deviceSequenceNumber", LongType, false) ::
  StructField("createdAt", TimestampType, false) :: Nil)

var streamData = eventhubs
  .select(from_json(decode($"body", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"enqueuedTime".as("enqueuedAt"))
  .withColumn("processedAt", lit(Timestamp.from(Instant.now)))

// COMMAND ----------

val gen2account = dbutils.widgets.get("storage-account")
spark.conf.set(
  s"fs.azure.account.key.$gen2account.dfs.core.windows.net",
  dbutils.secrets.get(scope = "MAIN", key = "storage-account-key"))
spark.conf.set("fs.azure.createRemoteFileSystemDuringInitialization", "true")
dbutils.fs.ls(s"abfss://streamingatscale@$gen2account.dfs.core.windows.net/")
spark.conf.set("fs.azure.createRemoteFileSystemDuringInitialization", "false")

// COMMAND ----------

sql("DROP TABLE IF EXISTS `" + dbutils.widgets.get("delta-table") + "`")

// COMMAND ----------

// You can also use a path instead of a table, see https://docs.azuredatabricks.net/delta/delta-streaming.html#append-mode
streamData
  .withColumn("storedAt", current_timestamp)
  .writeStream
  .outputMode("append")
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/streaming-delta/" + dbutils.widgets.get("delta-table"))
  .format("delta")
  .option("path", s"abfss://streamingatscale@$gen2account.dfs.core.windows.net/" + dbutils.widgets.get("delta-table"))
  .table(dbutils.widgets.get("delta-table"))

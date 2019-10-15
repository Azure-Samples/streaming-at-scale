// Databricks notebook source
dbutils.widgets.text("eventhub-consumergroup", "databricks", "Event Hubs consumer group")
dbutils.widgets.text("eventhub-maxEventsPerTrigger", "1000", "Event Hubs max events per trigger")

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

val schema = StructType(
  StructField("eventId", StringType, false) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType, false)))) ::
  StructField("value", StringType, false) ::
  StructField("type", StringType, false) ::
  StructField("deviceId", StringType, false) ::
  StructField("deviceSequenceNumber", LongType, false) ::
  StructField("createdAt", TimestampType, false) :: Nil)

val watermarkColumn = "enqueuedAt"

val streamData = eventhubs
  .select(from_json(decode($"body", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"enqueuedTime".as("enqueuedAt"))
  .withWatermark(watermarkColumn, "10 seconds")
  // watermark column must be part of dropDuplicates, or aggregation state will grow indefinitely!
  .dropDuplicates("eventId", watermarkColumn)
  .withColumn("processedAt", current_timestamp)

// COMMAND ----------

val eventHubsConfWrite = EventHubsConf(dbutils.secrets.get(scope = "MAIN", key = "event-hubs-write-connection-string"))

val query = 
streamData
  .select(to_json(struct($"*")).as("body"))
  .writeStream
  .format("eventhubs")
  .outputMode("append")
  .options(eventHubsConfWrite.toMap)
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/eventhubs-to-eventhubs")
  .start()

// Databricks notebook source
dbutils.widgets.text("cosmosdb-endpoint", "https://MYACCOUNT.documents.azure.com", "Cosmos DB endpoint")
dbutils.widgets.text("cosmosdb-database", "streaming", "Cosmos DB database")
dbutils.widgets.text("cosmosdb-collection", "rawdata", "Cosmos DB collection")
dbutils.widgets.text("eventhub-consumergroup", "cosmos", "Event Hubs consumer group")
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
import java.time.Instant
import java.sql.Timestamp

val schema = StructType(
  StructField("eventId", StringType) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType)))) ::
  StructField("value", StringType) ::
  StructField("type", StringType) ::
  StructField("deviceId", StringType) ::
  StructField("createdAt", TimestampType) :: Nil)

val streamData = eventhubs
  .select(from_json(decode($"body", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"enqueuedTime".as("enqueuedAt"))
  .withColumn("processedAt", lit(Timestamp.from(Instant.now)))

// COMMAND ----------

// Configure the connection to your collection in Cosmos DB.
// Please refer to https://github.com/Azure/azure-cosmosdb-spark/wiki/Configuration-references
// for the description of the available configurations.
val cosmosDbConfig = Map(
  "Endpoint" -> dbutils.widgets.get("cosmosdb-endpoint"),
  "Masterkey" -> dbutils.secrets.get(scope = "MAIN", key = "cosmosdb-write-master-key"),
  "Database" -> dbutils.widgets.get("cosmosdb-database"),
  "Collection" -> dbutils.widgets.get("cosmosdb-collection")
)

// COMMAND ----------

// Convert Timestamp columns to Date type for Cosmos DB compatibility
var streamDataMutated = streamData
for (c <- streamData.schema.fields filter { _.dataType.isInstanceOf[org.apache.spark.sql.types.TimestampType] } map {_.name}) { 
  streamDataMutated = streamDataMutated.withColumn(c, date_format(col(c), "yyyy-MM-dd'T'HH:mm:ss.SSSX"))
}

// COMMAND ----------

import com.microsoft.azure.cosmosdb.spark.streaming.CosmosDBSinkProvider

streamDataMutated
  .writeStream
  .format(classOf[CosmosDBSinkProvider].getName)
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/streaming-cosmosdb")
  .outputMode("append")
  .options(cosmosDbConfig)
  .start()

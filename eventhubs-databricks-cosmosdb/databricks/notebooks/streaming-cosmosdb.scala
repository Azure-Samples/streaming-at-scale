// Databricks notebook source
dbutils.widgets.text("cosmosdb-endpoint", "https://MYACCOUNT.documents.azure.com", "Cosmos DB endpoint")
dbutils.widgets.text("cosmosdb-database", "streaming", "Cosmos DB database")
dbutils.widgets.text("cosmosdb-collection", "rawdata", "Cosmos DB collection")
dbutils.widgets.text("eventhub-consumergroup", "cosmos", "Event Hubs consumer group")

// COMMAND ----------

import org.apache.spark.eventhubs.{ EventHubsConf, EventPosition }

val eventHubsConf = EventHubsConf(dbutils.secrets.get(scope = "MAIN", key = "event-hubs-read-connection-string"))
  .setStartingPosition(EventPosition.fromStartOfStream)
  .setConsumerGroup(dbutils.widgets.get("eventhub-consumergroup"))
  
val eventhubs = spark.readStream
  .format("eventhubs")
  .options(eventHubsConf.toMap)
  .load()

// COMMAND ----------

import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
val schema = StructType(
  StructField("eventId", StringType) ::
  StructField("complexData", StructType((1 to 22).map(i => StructField(s"moreData$i", DoubleType)))) ::
  StructField("value", StringType) ::
  StructField("type", StringType) ::
  StructField("deviceId", StringType) ::
  StructField("createdAt", StringType) :: Nil)
val jsons = eventhubs
      .select(from_json(decode($"body", "UTF-8"), schema).as("eventData"), $"*")
      .select($"eventData.*", $"offset", $"sequenceNumber", $"publisher", $"partitionKey") 

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

import com.microsoft.azure.cosmosdb.spark.streaming.CosmosDBSinkProvider

val cosmosdb = jsons
  .writeStream
  .format(classOf[CosmosDBSinkProvider].getName)
  .option("checkpointLocation", "dbfs:/checkpoints/streaming-delta")
  .outputMode("append")
  .options(cosmosDbConfig)
  .start()

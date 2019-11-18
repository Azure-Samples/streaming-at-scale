// Databricks notebook source
dbutils.widgets.text("kafka-servers", "")
dbutils.widgets.text("kafka-topics", "streaming")
dbutils.widgets.text("kafka-sasl-mechanism", "")
dbutils.widgets.text("kafka-security-protocol", "")
dbutils.widgets.text("cosmosdb-endpoint", "https://MYACCOUNT.documents.azure.com", "Cosmos DB endpoint")
dbutils.widgets.text("cosmosdb-database", "streaming", "Cosmos DB database")
dbutils.widgets.text("cosmosdb-collection", "rawdata", "Cosmos DB collection")

// COMMAND ----------

import java.util.UUID.randomUUID

val data = spark.readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", dbutils.widgets.get("kafka-servers"))
  .option("kafka.sasl.mechanism", dbutils.widgets.get("kafka-sasl-mechanism"))
  .option("kafka.security.protocol", dbutils.widgets.get("kafka-security-protocol"))
  .option("kafka.sasl.jaas.config", dbutils.secrets.get(scope = "MAIN", key = "kafka-sasl-jaas-config"))
  .option("kafka.group.id", randomUUID().toString)
  .option("subscribe", dbutils.widgets.get("kafka-topics"))
  .option("startingOffsets", "earliest")
  .load()

// COMMAND ----------

import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import java.time.Instant
import java.sql.Timestamp

val schema = StructType(
  StructField("eventId", StringType, false) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType, false)))) ::
  StructField("value", DoubleType, false) ::
  StructField("type", StringType, false) ::
  StructField("deviceId", StringType, false) ::
  StructField("deviceSequenceNumber", LongType, false) ::
  StructField("createdAt", TimestampType, false) :: Nil)

val streamData = data
  .select(from_json(decode($"value", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"timestamp".as("enqueuedAt"))
  .withColumn("processedAt", lit(Timestamp.from(Instant.now)))
  // Unique ID column for Upsert
  .withColumn("id", 'eventId)

// COMMAND ----------

// Configure the connection to your collection in Cosmos DB.
// Please refer to https://github.com/Azure/azure-cosmosdb-spark/wiki/Configuration-references
// for the description of the available configurations.
val cosmosDbConfig = Map(
  "Endpoint" -> dbutils.widgets.get("cosmosdb-endpoint"),
  "ConnectionMode" -> "DirectHttps",
  "Upsert" -> "true",
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
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/kafka-to-cosmosdb")
  .outputMode("append")
  .options(cosmosDbConfig)
  .start()

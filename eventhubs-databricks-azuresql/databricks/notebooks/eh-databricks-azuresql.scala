// Databricks notebook source
dbutils.widgets.text("eventhub-consumergroup", "azuresql")
dbutils.widgets.text("azuresql-servername", "servername")
dbutils.widgets.text("azuresql-tablename", "tablename")
dbutils.widgets.text("eventhub-maxEventsPerTrigger", "1000", "Event Hubs max events per trigger")

// COMMAND ----------

import org.apache.spark.eventhubs._

val ehConf = EventHubsConf(dbutils.secrets.get(scope = "MAIN", key = "event-hubs-read-connection-string"))
  .setConsumerGroup(dbutils.widgets.get("eventhub-consumergroup"))
  .setStartingPosition(EventPosition.fromEndOfStream)
  .setMaxEventsPerTrigger(dbutils.widgets.get("eventhub-maxEventsPerTrigger").toLong)

val reader = spark.readStream
  .format("eventhubs")
  .options(ehConf.toMap)
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

// COMMAND ----------

import java.util.UUID.randomUUID

val generateUUID = udf(() => randomUUID().toString)

val dataToWrite = reader
  .select(from_json(decode($"body", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"offset", $"sequenceNumber", $"publisher", $"partitionKey".cast(IntegerType), $"enqueuedTime".as("enqueuedAt")) 
  .withColumn("createdAt", $"createdAt".cast(TimestampType))
  .withColumn("processedAt", current_timestamp())
  .withColumn("StoredAt", current_timestamp()) 
  .withColumn("BatchId", lit(randomUUID().toString))
  .select($"BatchId", $"eventId".as("EventId"), $"Type", $"DeviceId", $"CreatedAt", $"Value", $"ComplexData", $"EnqueuedAt", $"ProcessedAt", $"StoredAt", $"PartitionKey".as("PartitionId"))

// COMMAND ----------

import java.util.UUID.randomUUID
import com.microsoft.azure.sqldb.spark.bulkcopy.BulkCopyMetadata
import com.microsoft.azure.sqldb.spark.config.Config
import com.microsoft.azure.sqldb.spark.connect._
import org.apache.spark.sql._

val generateUUID = udf(() => randomUUID().toString)

val WriteToSQLQuery  = dataToWrite.writeStream.foreachBatch((batchDF: DataFrame, batchId: Long) => {
  val serverName:String = dbutils.widgets.get("azuresql-servername")
  val tableName:String = dbutils.widgets.get("azuresql-tablename")

  val bulkCopyConfig = Config(Map(
    "url"               -> s"$serverName.database.windows.net",
    "user"              -> "serveradmin",
    "password"          -> dbutils.secrets.get(scope = "MAIN", key = "azuresql-pass"),
    "databaseName"      -> "streaming",
    "dbTable"           -> s"dbo.$tableName",
    "bulkCopyBatchSize" -> "2500",
    "bulkCopyTableLock" -> "true",
    "bulkCopyTimeout"   -> "600"
  ))   
  
  // Make sure BatchID and StoredAt are evaluated at batch level
  val newDf = batchDF
    .withColumn("BatchId", lit(randomUUID().toString))
    .withColumn("StoredAt", current_timestamp())
    .withColumn("PartitionId", lit((batchId % 16).toInt)) 

  var bulkCopyMetadata = new BulkCopyMetadata
  bulkCopyMetadata.addColumnMetadata(1, "BatchId", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(2, "EventId", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(3, "Type", java.sql.Types.NVARCHAR, 10, 0)
  bulkCopyMetadata.addColumnMetadata(4, "DeviceId", java.sql.Types.NVARCHAR, 100, 0)
  bulkCopyMetadata.addColumnMetadata(5, "CreatedAt", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(6, "Value", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(7, "ComplexData", java.sql.Types.NVARCHAR, -1, 0)
  bulkCopyMetadata.addColumnMetadata(8, "EnqueuedAt", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(9, "ProcessedAt", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(10, "StoredAt", java.sql.Types.NVARCHAR, 128, 0)
  bulkCopyMetadata.addColumnMetadata(11, "PartitionId", java.sql.Types.INTEGER, 128, 0)  
  
  newDf.bulkCopyToSqlDB(bulkCopyConfig, bulkCopyMetadata)  
})

var streamingQuery = WriteToSQLQuery.start()



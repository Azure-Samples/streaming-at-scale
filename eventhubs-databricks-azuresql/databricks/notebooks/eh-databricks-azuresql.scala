// Databricks notebook source
dbutils.widgets.text("eventhub-consumergroup", "azuresql")
dbutils.widgets.text("azuresql-servername", "servername")
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

val dataToWrite = reader
  .select(from_json(decode($"body", "UTF-8"), schema).as("eventData"), $"*")
  .select($"eventData.*", $"offset", $"sequenceNumber", $"publisher", $"partitionKey".cast(IntegerType), $"enqueuedTime".as("enqueuedAt")) 
  .withColumn("createdAt", $"createdAt".cast(TimestampType))
  .withColumn("processedAt", current_timestamp())

// COMMAND ----------

import java.util.Properties
import java.sql.DriverManager
import org.apache.spark.sql._
import java.util.UUID.randomUUID

val WriteToSQLQuery  = dataToWrite.writeStream.foreach(new ForeachWriter[Row] {
  var connection:java.sql.Connection = _
  var statement:java.sql.Statement = _
  
  val jdbcUsername = "serveradmin"
  val jdbcPassword = dbutils.secrets.get(scope = "MAIN", key = "azuresql-pass")
  val jdbcServername = dbutils.widgets.get("azuresql-servername")
  val jdbcPort = 1433
  val jdbcDatabase = "streaming"
  val tableName = "dbo.rawdata"
  val driver = "com.microsoft.sqlserver.jdbc.SQLServerDriver"
  val jdbc_url = s"jdbc:sqlserver://${jdbcServername}.database.windows.net:${jdbcPort};database=${jdbcDatabase};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
  var batchId = ""
  
  def open(partitionId: Long, version: Long):Boolean = {
    Class.forName(driver)
    connection = DriverManager.getConnection(jdbc_url, jdbcUsername, jdbcPassword)
    statement = connection.createStatement
    batchId = quote(randomUUID().toString)
    true
  }
  
  def quote(value: Any): String = {
    "'" + value.toString + "'"
  }

  def process(value: Row): Unit = {    
    val eventId = quote(value(0))
    val complexData = quote(value(1))
    val value1 = quote(value(2))
    val type1 = quote(value(3))
    val deviceId = quote(value(4))
    val createdAt = quote(value(5))    
    val enqueuedAt = quote(value(10))        
    val processedAt = quote(value(11))
    val storedAt = "SYSDATETIME()"
    val partitionId = value(9).toString.toInt % 16

    val valueStr = List(batchId, eventId, type1, deviceId, createdAt, value1, complexData, enqueuedAt, processedAt, storedAt, partitionId).mkString(",")
    statement.addBatch("INSERT INTO " + tableName + " ([BatchId], [EventId], [Type], [DeviceId], [CreatedAt], [Value], [ComplexData], [EnqueuedAt], [ProcessedAt], [StoredAt], [PartitionId]) VALUES (" + valueStr + ")")   
  }

  def close(errorOrNull: Throwable): Unit = {
    statement.executeBatch
    connection.close
  }
})

var streamingQuery = WriteToSQLQuery.start()

// COMMAND ----------



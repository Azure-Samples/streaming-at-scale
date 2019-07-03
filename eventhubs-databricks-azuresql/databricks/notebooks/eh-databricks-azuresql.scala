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
  var statement:java.sql.PreparedStatement = _
  
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
    statement = connection.prepareStatement("INSERT INTO " + tableName + " ([BatchId], [EventId], [Type], [DeviceId], [CreatedAt], [Value], [ComplexData], [EnqueuedAt], [ProcessedAt], [StoredAt], [PartitionId]) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, SYSDATETIME(), ?)")
    batchId = randomUUID().toString
    true
  }
  
  def process(value: Row): Unit = {    
    val eventId = value(0).toString
    val complexData = value(1).toString
    val value1 = value(2).toString
    val type1 = value(3).toString
    val deviceId = value(4).toString
    val createdAt = value(5).toString
    val enqueuedAt = value(10).toString
    val processedAt = value(11).toString
    val partitionId = value(9).toString.toInt % 16

    statement.setString(1, batchId)
    statement.setString(2, eventId)
    statement.setString(3, type1)
    statement.setString(4, deviceId)    
    statement.setString(5, createdAt)
    statement.setString(6, value1)
    statement.setString(7, complexData)
    statement.setString(8, enqueuedAt)
    statement.setString(9, processedAt)
    statement.setInt(10, partitionId)
    
    statement.addBatch 
  }

  def close(errorOrNull: Throwable): Unit = {
    statement.executeBatch
    connection.close
  }
})

var streamingQuery = WriteToSQLQuery.start()

// COMMAND ----------



// Databricks notebook source
dbutils.widgets.text("eventhub-consumergroup", "azuresql")
dbutils.widgets.text("azuresql-servername", "servername")

// COMMAND ----------

import org.apache.spark.eventhubs._

val ehConf = EventHubsConf(dbutils.secrets.get(scope = "MAIN", key = "event-hubs-read-connection-string"))
  .setConsumerGroup(dbutils.widgets.get("eventhub-consumergroup"))
  .setStartingPosition(EventPosition.fromEndOfStream)

val reader = spark.readStream
  .format("eventhubs")
  .options(ehConf.toMap)
  .load()

val messages = reader.select($"body" cast "string", $"enqueuedTime")

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

val messages_withSchema = messages
      .select(from_json(col("body"), schema).alias("data"), $"enqueuedTime")

// COMMAND ----------

import java.time.Instant
import java.sql.Timestamp

def getCurrentTime (): Timestamp = {
  return new Timestamp(Instant.now().toEpochMilli())
}

val getCurrentTimeUDF = udf(() => getCurrentTime())

// COMMAND ----------

val dataToWrite = messages_withSchema
  .select("enqueuedTime", "data.*")
  .withColumn("createdAt", $"createdAt".cast(TimestampType))
  .withColumn("processedAt", getCurrentTimeUDF())

// COMMAND ----------

import java.util.Properties
import java.sql.DriverManager
import org.apache.spark.sql._

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

  def open(partitionId: Long, version: Long):Boolean = {
    Class.forName(driver)
    connection = DriverManager.getConnection(jdbc_url, jdbcUsername, jdbcPassword)
    statement = connection.createStatement
    true
  }

  def process(value: Row): Unit = {
    val enqueuedTime = value(0)
    val eventId = value(1)
    val complexData = value(2)
    val value1 = value(3)
    val type1 = value(4)
    val deviceId = value(5)
    val createdAt = value(6)
    val processedAt = value(7)

    val valueStr = "'" + enqueuedTime + "'," + "'" + eventId + "'," + "'" + complexData + "'," + "'" + value1 + "'," + "'" + type1 + "'," + "'" + deviceId + "'," + "'" + createdAt + "'," + "'" + processedAt + "'"
    statement.execute("INSERT INTO " + tableName + " (EnqueuedAt, EventId, ComplexData, Value, Type, DeviceId, CreatedAt, ProcessedAt) VALUES (" + valueStr + ")")   
  }

  def close(errorOrNull: Throwable): Unit = {
    connection.close
  }
})

var streamingQuery = WriteToSQLQuery.start()

// COMMAND ----------



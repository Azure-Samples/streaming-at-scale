// Databricks notebook source
dbutils.widgets.text("test-output-path", "dbfs:/test-output/test-output.txt", "DBFS location to store assertion results")
dbutils.widgets.text("kafka-servers", "")
dbutils.widgets.text("kafka-topics", "streaming")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")
dbutils.widgets.text("assert-duplicate-fraction", "0", "Assert max proportion of duplicate events")
dbutils.widgets.text("assert-outofsequence-fraction", "0", "Assert max proportion of out-of-sequence events")

// COMMAND ----------

val streamingData = spark
  .readStream
  .format("kafka")
  .option("kafka.bootstrap.servers", dbutils.widgets.get("kafka-servers"))
  .option("subscribe", dbutils.widgets.get("kafka-topics"))
  .option("startingOffsets", "earliest")
  .load()

// COMMAND ----------

import org.apache.spark.sql._
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import java.util.UUID.randomUUID

val schema = StructType(
  StructField("eventId", StringType, false) ::
  StructField("complexData", StructType((0 to 22).map(i => StructField(s"moreData$i", DoubleType, false)))) ::
  StructField("value", DoubleType, false) ::
  StructField("type", StringType, false) ::
  StructField("deviceId", StringType, false) ::
  StructField("deviceSequenceNumber", LongType, false) ::
  // Parse time fields as string as workaround for https://issues.apache.org/jira/browse/SPARK-17914 
  // (incorrectly marked as resolved as of Spark 2.4.3, see Jira comments)
  StructField("createdAt", StringType, false) ::
  StructField("enqueuedAt", StringType, false) ::
  StructField("processedAt", StringType, false) ::
  StructField("processedAt2", StringType, false) ::
  Nil)

val stagingTable = "tempresult_" + randomUUID().toString.replace("-","_")

var query = streamingData
  .select(from_json(decode($"value", "UTF-8"), schema).as("eventData"), $"*")
  // When consuming from the output of hdinsightkafka-streamanalytics-hdinsightkafka pipeline, 'enqueuedAt' will haven been
  // set when reading from the first eventhub, and the enqueued timestamp of the second eventhub is then the 'storedAt' time
  .select($"eventData.*", $"timestamp".as("storedAt"))
  // Continue workaround for https://issues.apache.org/jira/browse/SPARK-17914 
  .withColumn("createdAt", $"createdAt".cast(TimestampType))
  .withColumn("enqueuedAt", $"enqueuedAt".cast(TimestampType))
  .withColumn("processedAt", $"processedAt".cast(TimestampType))
  .withColumn("processedAt2", $"processedAt2".cast(TimestampType))
  // Write stream as a delta table
  .writeStream
  .format("delta")
  .option("checkpointLocation", "dbfs:/streaming_at_scale/checkpoints/verify-kafka/" + stagingTable)
  .table(stagingTable)

// COMMAND ----------

import java.util.Calendar


println("Waiting while stream collects data")
while (query.isActive) {
  if (!query.status.isDataAvailable) {
    println(Calendar.getInstance().getTime())
    println("No more data available")
    // https://stackoverflow.com/questions/45717433/stop-structured-streaming-query-gracefully
    while (query.status.isTriggerActive) {
      println(Calendar.getInstance().getTime())
      println("Trigger is active")
      Thread.sleep(1000)
    }
    query.stop
  }
  Thread.sleep(1000)
}
println("Query stopped")
if (query.exception.nonEmpty) {
  throw query.exception.get
}
if (table(stagingTable).count == 0) {
  throw new AssertionError("No data collected")
}

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "test-output-path" -> dbutils.widgets.get("test-output-path"),
    "input-table" -> stagingTable,
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> dbutils.widgets.get("assert-latency-milliseconds"),
    "assert-duplicate-fraction" -> dbutils.widgets.get("assert-duplicate-fraction"),
    "assert-outofsequence-fraction" -> dbutils.widgets.get("assert-outofsequence-fraction")
))

// COMMAND ----------

sql("DROP TABLE `" + stagingTable + "`")

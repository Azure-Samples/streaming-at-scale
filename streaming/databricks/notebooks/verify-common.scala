// Databricks notebook source
dbutils.widgets.text("verify-settings", "{}", "Verification job settings")
dbutils.widgets.text("input-table", "stream_data", "Spark table to pass stream data")

//

import org.json4s
import org.json4s.JValue
import org.json4s.jackson.JsonMethods.parse

implicit lazy val formats = org.json4s.DefaultFormats

case class Settings (
  testOutputPath: Option[String],
  assertEventsPerSecond: Option[Double],
  assertLatencyMilliseconds: Option[Double],
  assertDuplicateFraction: Option[Double],
  assertOutOfSequenceFraction: Option[Double],
  assertMissingFraction: Option[Double]
)

val settings = parse(dbutils.widgets.get("verify-settings")).extract[Settings]

// DBFS location to store assertion results
val testOutputPath: String = settings.testOutputPath getOrElse "dbfs:/test-output/test-output.txt"

// COMMAND ----------

if (dbutils.secrets.list("MAIN").exists { s => s.key == "storage-account-key"}) {
  spark.conf.set("fs.azure.account.key", dbutils.secrets.get(scope = "MAIN", key = "storage-account-key"))
}

// COMMAND ----------

import scala.collection.mutable.ListBuffer

var assertionsFailed = new ListBuffer[String]()

// COMMAND ----------

val assertEventsPerSecond = settings.assertEventsPerSecond getOrElse 900d

// Fetch event data, limiting to one hour of data
val inputData = table(dbutils.widgets.get("input-table"))
  .limit(((assertEventsPerSecond getOrElse 1000d) * 3600).toInt)
  .cache

// COMMAND ----------

import org.apache.spark.sql.functions._
import org.apache.spark.sql.expressions.Window

val storedByMinuteStats = inputData
    .withColumn("storedAtMinute", (floor(unix_timestamp('storedAt) / 60) * 60).cast("timestamp"))
    .withColumn("latency", 'storedAt.cast("double") - 'enqueuedAt.cast("double"))
    .groupBy('storedAtMinute)
    .agg(
      (count('eventId)/60).as("events_per_second"),
      avg('latency).as("avg_latency_s")
    )
    .orderBy('storedAtMinute)
    .cache

display(storedByMinuteStats)

// COMMAND ----------

val storedStats = storedByMinuteStats.agg(
  count('storedAtMinute).as("minutesWithData"),
  max('events_per_second).as("maxThroughputEventsPerSecond"),
  min('avg_latency_s).as("minLatencySeconds")
).cache

case class StoredStats(
  minutesWithData: Option[Long],
  maxThroughputEventsPerSecond: Option[Double],
  minLatencySeconds: Option[Double]
)

display(storedStats)

// COMMAND ----------

val stats = storedStats.as[StoredStats].head

if (assertEventsPerSecond.nonEmpty) {
  val expected = assertEventsPerSecond.get
  val actual = stats.maxThroughputEventsPerSecond
  if (actual.isEmpty || (actual.get < expected)) {
    assertionsFailed += s"min throughput per second: expected min $expected, got $actual"
  }
}

val assertLatencyMilliseconds = settings.assertLatencyMilliseconds getOrElse 15000d
if (assertLatencyMilliseconds.nonEmpty) {
  val expected = assertLatencyMilliseconds.get
  val actual = stats.minLatencySeconds
  if (actual.isEmpty || ((actual.get * 1000) > expected)) {
    assertionsFailed += s"max latency in milliseconds: expected max $expected milliseconds, got $actual seconds"
  }
}

// COMMAND ----------

val duplicates = inputData
    .groupBy('eventId)
    .agg(count('eventId).as("count"))
    .where('count > 1)
    .count

val duplicateFraction = duplicates.toDouble / inputData.count

val assertDuplicateFraction = settings.assertDuplicateFraction getOrElse 0d
if (assertDuplicateFraction.nonEmpty) {
  val expected = assertDuplicateFraction.get
  if (duplicateFraction > expected) {
    assertionsFailed += s"fraction of duplicate events: expected max $expected, got $duplicateFraction"
  }
}

// COMMAND ----------

val timeSequence = Window.partitionBy("deviceId").orderBy('storedAt, 'deviceSequenceNumber)

val outOfSequence = inputData
  .withColumn("deviceSequenceNumberDelta", 'deviceSequenceNumber - lag('deviceSequenceNumber, 1).over(timeSequence))
  // in-sequence events will have delta=1, duplicate events will have delta=0 (ignore them as they are checked separately)
  .filter('deviceSequenceNumberDelta > 1)
  .count

val outOfSequenceFraction = outOfSequence.toDouble / inputData.count

val assertOutOfSequenceFraction = settings.assertOutOfSequenceFraction getOrElse 0d
if (assertOutOfSequenceFraction.nonEmpty) {
  val expected = assertOutOfSequenceFraction.get
  if (outOfSequenceFraction > expected) {
    assertionsFailed += s"fraction of out-of-sequence events: expected max $expected, got $outOfSequenceFraction"
  }
}

// COMMAND ----------

val deviceSequence = Window.partitionBy("deviceId").orderBy('deviceSequenceNumber)
val devicePartition = Window.partitionBy("deviceId")

val missingEvents = inputData
  // Discard oldest 10% and newest 10% of events since events may appear missing because of ordering issues
  .withColumn("orderInDevice", row_number().over(deviceSequence))
  .withColumn("countForDevice", count("*").over(devicePartition))
  .withColumn("fractionInOrder", 'orderInDevice.cast("double") / 'countForDevice)
  .filter('fractionInOrder >= 0.1 and 'fractionInOrder <= 0.9)
  .withColumn("deviceSequenceNumberDelta", 'deviceSequenceNumber - lag('deviceSequenceNumber, 1).over(deviceSequence))
  // in-sequence events will have delta=1, duplicate events will have delta=0 (ignore them as they are checked separately)
  .filter('deviceSequenceNumberDelta > 1)
  .count

val missingFraction = missingEvents.toDouble / inputData.count

val assertMissingFraction = settings.assertMissingFraction getOrElse 0d
if (assertMissingFraction.nonEmpty) {
  val expected = assertMissingFraction.get
  if (missingFraction > expected) {
    assertionsFailed += s"fraction of missing events: expected max $expected, got $missingFraction"
  }
}

// COMMAND ----------

println("Writing test result file")

dbutils.fs.put(testOutputPath, assertionsFailed.mkString("\n"), overwrite=true)

if (!assertionsFailed.isEmpty) {
   println(s"Test assertion(s) failed: ${assertionsFailed.mkString(";")}")
}

// COMMAND ----------

dbutils.notebook.exit("SUCCESS")

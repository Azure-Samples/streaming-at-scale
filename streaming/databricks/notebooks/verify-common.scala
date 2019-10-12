// Databricks notebook source
dbutils.widgets.text("input-table", "stream_data", "Spark table to pass stream data")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")
dbutils.widgets.text("assert-duplicate-fraction", "0", "Assert max proportion of duplicate events")
dbutils.widgets.text("assert-outofsequence-fraction", "0", "Assert max proportion of out-of-sequence events")

// COMMAND ----------

if (dbutils.secrets.list("MAIN").exists { s => s.key == "storage-account-key"}) {
  spark.conf.set("fs.azure.account.key", dbutils.secrets.get(scope = "MAIN", key = "storage-account-key"))
}

// COMMAND ----------

val inputData = table(dbutils.widgets.get("input-table")).cache

// COMMAND ----------

import scala.collection.mutable.ListBuffer

def asOptionalDouble (s:String) = if (s == null || s == "") None else Some(s.toDouble)
def getWidgetAsDouble (w:String) = asOptionalDouble(dbutils.widgets.get(w))

var assertionsFailed = new ListBuffer[String]()

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

val assertEventsPerSecond = getWidgetAsDouble("assert-events-per-second")
if (assertEventsPerSecond.nonEmpty) {
  val expected = assertEventsPerSecond.get
  val actual = stats.maxThroughputEventsPerSecond
  if (actual.isEmpty || (actual.get < expected)) {
    assertionsFailed += s"min throughput per second: expected min $expected, got $actual"
  }
}

val assertLatencyMilliseconds = getWidgetAsDouble("assert-latency-milliseconds")
if (assertLatencyMilliseconds.nonEmpty) {
  val expected = assertLatencyMilliseconds.get
  val actual = stats.minLatencySeconds
  if (actual.isEmpty || ((actual.get * 1000) > expected)) {
    assertionsFailed += s"max latency in milliseconds: expected max $expected, got $actual"
  }
}

// COMMAND ----------

val duplicates = inputData
    .groupBy('eventId)
    .agg(count('eventId).as("count"))
    .where('count > 1)
    .count

val duplicateFraction = duplicates.toDouble / inputData.count

val assertDuplicateFraction = getWidgetAsDouble("assert-duplicate-fraction")
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

val assertOutOfSequenceFraction = getWidgetAsDouble("assert-outofsequence-fraction")
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

val assertMissingFraction = Some(0d)
if (assertMissingFraction.nonEmpty) {
  val expected = assertMissingFraction.get
  if (missingFraction > expected) {
    assertionsFailed += s"fraction of missing events: expected max $expected, got $missingFraction"
  }
}

// COMMAND ----------

assert(assertionsFailed.isEmpty, s"Test assertion(s) failed: ${assertionsFailed.mkString(";")}")

// COMMAND ----------

dbutils.notebook.exit("SUCCESS")

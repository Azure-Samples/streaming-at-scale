// Databricks notebook source
dbutils.widgets.text("input-table", "stream_data", "Spark table to pass stream data")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")

// COMMAND ----------

if (dbutils.secrets.list("MAIN").exists { s => s.key == "storage-account-key"}) {
  spark.conf.set("fs.azure.account.key", dbutils.secrets.get(scope = "MAIN", key = "storage-account-key"))
}

// COMMAND ----------

val streamData = table(dbutils.widgets.get("input-table"))

// COMMAND ----------

import org.apache.spark.sql.functions._

def asOptionalDouble (s:String) = if (s == null || s == "") None else Some(s.toDouble)
val assertEventsPerSecond = asOptionalDouble(dbutils.widgets.get("assert-events-per-second"))
val assertLatencyMilliseconds = asOptionalDouble(dbutils.widgets.get("assert-latency-milliseconds"))

val streamStatistics = streamData
    .withColumn("storedAtMinute", (floor(unix_timestamp('storedAt) / 60)  * 60).cast("timestamp"))
    .withColumn("latency", 'storedAt.cast("double") - 'enqueuedAt.cast("double"))
    .groupBy('storedAtMinute)
    .agg(
      (count('eventId)/60).as("events_per_second"),
      avg('latency).as("avg_latency_s")
    )
    .orderBy('storedAtMinute)
    .cache

val globalStats = streamStatistics.agg(
  count('storedAtMinute).as("minutesWithData"),
  max('events_per_second).as("maxThroughputEventsPerSecond"),
  min('avg_latency_s).as("minLatencySeconds")
).cache

display(globalStats)

// COMMAND ----------

display(streamStatistics)

// COMMAND ----------

case class GlobalStats(
  minutesWithData: Option[Long],
  maxThroughputEventsPerSecond: Option[Double],
  minLatencySeconds: Option[Double]
)
val stats = globalStats.as[GlobalStats].head

var assertionsPassed = true
if (assertEventsPerSecond.nonEmpty) {
  if (stats.maxThroughputEventsPerSecond.isEmpty ||
      (stats.maxThroughputEventsPerSecond.get < assertEventsPerSecond.get)) {
    println("FAILED: min throughput")
    assertionsPassed = false
  }
}
if (assertLatencyMilliseconds.nonEmpty) {
  if (stats.minLatencySeconds.isEmpty ||
      ((stats.minLatencySeconds.get * 1000) > assertLatencyMilliseconds.get)) {
    println("FAILED: max latency")
    assertionsPassed = false
  }
}

// COMMAND ----------

assert (assertionsPassed, "Test assertion(s) failed")

// COMMAND ----------

dbutils.notebook.exit("SUCCESS")

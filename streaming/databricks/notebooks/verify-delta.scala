// Databricks notebook source
dbutils.widgets.text("delta-table", "streaming_events", "Delta table containing events")
dbutils.widgets.text("assert-events-per-second", "900", "Assert min events per second (computed over 1 min windows)")
dbutils.widgets.text("assert-latency-milliseconds", "15000", "Assert max latency in milliseconds (averaged over 1 min windows)")

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "input-table" -> dbutils.widgets.get("delta-table"),
    "assert-events-per-second" -> dbutils.widgets.get("assert-events-per-second"),
    "assert-latency-milliseconds" -> dbutils.widgets.get("assert-latency-milliseconds")
))

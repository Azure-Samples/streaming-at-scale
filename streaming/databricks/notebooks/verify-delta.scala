// Databricks notebook source
dbutils.widgets.text("delta-table", "streaming_events", "Delta table containing events")

// COMMAND ----------

dbutils.notebook.run("verify-common", 0, Map(
    "input-table" -> dbutils.widgets.get("delta-table")
))

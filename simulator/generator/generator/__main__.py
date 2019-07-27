import os
import time
import datetime

from pyspark.sql import SparkSession
from pyspark.sql.functions import *

spark = (SparkSession
  .builder
  .appName("DataGenerator")
  .config("spark.jars", os.environ['SPARK_JARS'])
  .getOrCreate()
  )

ratestream = (spark
  .readStream
  .format("rate")
  .option("rowsPerSecond", os.environ['EVENTS_PER_SECOND'])
  .load()
   )

query = (ratestream
  .withColumn("deviceId", expr("'contoso://' || (value % 10)"))
  .withColumn("partition", expr("value % 10"))
  .withColumn("value", rand())
  .selectExpr("to_json(struct(deviceId, timestamp, value)) AS value", "partition")
  .writeStream
  .partitionBy("partition")
  .format("kafka")
  .option("kafka.bootstrap.servers", os.environ['KAFKA_SERVERS'])
  .option("topic", os.environ['KAFKA_TOPIC'])
  .option("checkpointLocation", "/tmp/checkpoint")
  .start()
  )

lastTimestamp = ""
nextPrintedTimestamp = time.monotonic()
lastPrintedTimestamp = 0
lastPrintedTimestampRows = 0
totalRows = 0
while (query.isActive):
  now = time.monotonic()
  for rp in query.recentProgress:
    if rp['timestamp'] > lastTimestamp:
      lastTimestamp = rp['timestamp']
      totalRows += rp['numInputRows']
  rps = (totalRows - lastPrintedTimestampRows) / (now - lastPrintedTimestamp)
  lastPrintedTimestamp = now
  nextPrintedTimestamp += 10
  if lastPrintedTimestamp > 0:
    print("%s %10.1f events/s" % (datetime.datetime.now().isoformat(), rps))
  lastPrintedTimestampRows = totalRows
  time.sleep(nextPrintedTimestamp - now)


print(query.exception())

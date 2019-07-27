import os
import time
import datetime
import uuid

from pyspark.sql import SparkSession
import pyspark.sql.functions as F
from pyspark.sql.types import StringType

complexDataCount = int(os.environ.get("COMPLEX_DATA_COUNT") or 23)
duplicateEveryNEvents = int(os.environ.get("DUPLICATE_EVERY_N_EVENTS") or 0)

generate_uuid = F.udf(lambda : str(uuid.uuid4()), StringType())

spark = (SparkSession
  .builder
  .appName("DataGenerator")
  .config("spark.jars", os.environ['SPARK_JARS'])
  .getOrCreate()
  )

stream = (spark
  .readStream
  .format("rate")
  .option("rowsPerSecond", os.environ['EVENTS_PER_SECOND'])
  .load()
   )

stream = (stream
  .withColumn("deviceId", F.expr("'contoso://device-id-' || floor(rand() * 1000)"))
  .withColumn("type", F.explode(F.array(F.lit("TEMP"), F.lit("CO2"))))
  .withColumn("partition", F.expr("value % 10"))
  .withColumn("eventId", generate_uuid())
  .withColumn("createdAt", F.current_timestamp())
  .withColumn("value", F.rand() * 90 + 10)
  )

for i in range(complexDataCount):
  stream = stream.withColumn("moreData{}".format(i), F.rand() * 10)

stream = stream.withColumn("complexData", F.struct([F.col("moreData{}".format(i)) for i in range(complexDataCount)]))

#TODO
#if duplicateEveryNEvents > 0:
# stream = stream.withColumn("repeated", F.expr("explode(CASE WHEN rand() < {} THEN array(1,2) ELSE array(1) END)".format(duplicateEveryNEvents)))

query = (stream
  .selectExpr("to_json(struct(eventId, type, deviceId, createdAt, value, complexData)) AS value", "partition")
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

import os
import time
import datetime
import uuid
import json

from pyspark.sql import SparkSession
import pyspark.sql.functions as F
from pyspark.sql.types import StringType

executors = int(os.environ.get('EXECUTORS') or 1)
rowsPerSecond = int(os.environ.get('EVENTS_PER_SECOND') or 1000)
numberOfDevices = int(os.environ.get('NUMBER_OF_DEVICES') or 1000)
complexDataCount = int(os.environ.get("COMPLEX_DATA_COUNT") or 23)
duplicateEveryNEvents = int(os.environ.get("DUPLICATE_EVERY_N_EVENTS") or 0)

outputFormat = os.environ.get('OUTPUT_FORMAT') or "kafka"
outputOptions = json.loads(os.environ.get('OUTPUT_OPTIONS') or "{}")
secureOutputOptions = json.loads(os.environ.get('SECURE_OUTPUT_OPTIONS') or "{}")

generate_uuid = F.udf(lambda : str(uuid.uuid4()), StringType())

spark = (SparkSession
  .builder
  .master("local[%d]" % executors)
  .appName("DataGenerator")
  .getOrCreate()
  )

stream = (spark
  .readStream
  .format("rate")
  .option("rowsPerSecond", rowsPerSecond)
  .load()
   )
# Rate stream has columns "timestamp" and "value"

stream = (stream
  .withColumn("deviceId", F.concat(F.lit("contoso://device-id-"), F.expr("mod(value, %d)" % numberOfDevices)))
  .withColumn("type", F.expr("CASE WHEN rand()<0.5 THEN 'TEMP' ELSE 'CO2' END"))
  .withColumn("partitionKey", F.col("deviceId"))
  .withColumn("eventId", generate_uuid())
  # current_timestamp is later than rate stream timestamp, therefore more accurate to measure end-to-end latency
  .withColumn("createdAt", F.current_timestamp())
  .withColumn("value", F.rand() * 90 + 10)
  )

for i in range(complexDataCount):
  stream = stream.withColumn("moreData{}".format(i), F.rand() * 90 + 10)

stream = stream.withColumn("complexData", F.struct([F.col("moreData{}".format(i)) for i in range(complexDataCount)]))

if duplicateEveryNEvents > 0:
 stream = stream.withColumn("repeated", F.expr("CASE WHEN rand() < {} THEN array(1,2) ELSE array(1) END".format(1/duplicateEveryNEvents)))
 stream = stream.withColumn("repeated", F.explode("repeated"))

if outputFormat == "eventhubs":
  bodyColumn = "body"
else: #Kafka format
  bodyColumn = "value"

query = (stream
  .selectExpr("to_json(struct(eventId, type, deviceId, createdAt, value, complexData)) AS %s" % bodyColumn, "partitionKey")
  .writeStream
  .partitionBy("partitionKey")
  .format(outputFormat)
  .options(**outputOptions)
  .options(**secureOutputOptions)
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
  nextPrintedTimestamp += 60
  if lastPrintedTimestamp > 0:
    print("%s %10.1f events/s" % (datetime.datetime.now().isoformat(), rps))
  lastPrintedTimestampRows = totalRows
  time.sleep(nextPrintedTimestamp - now)

print(query.exception())

import os
from pyspark.sql import SparkSession

spark = (SparkSession
  .builder
  .appName("DataGenerator")
  .config("spark.jars", os.environ['SPARK_JARS'])
  .getOrCreate()
  )

ratestream = (spark
  .readStream
  .format("rate")
  .option("rowsPerSecond", 1)
  .load()
   )

query = (ratestream
  .selectExpr("cast(value as string) AS value")
  .writeStream
  .format("kafka")
  .option("kafka.bootstrap.servers", os.environ['KAFKA_SERVERS'])
  .option("topic", os.environ['KAFKA_TOPIC'])
  .option("checkpointLocation", "/tmp/checkpoint")
  .start()
  )

query.awaitTermination()


# Databricks notebook source
# =================================================================
#
#  Data Preprocessor for SAS Telemetry Data 
#
#  The code will run structured streaming with following logic
#  1. Read SAS Lab Telemetry data (JSON) from SOURCE_STREAM_FILES_FOLDER using Spark Structured Streaming(autoloader)
#  2. Split the data based companyId and type columns in the telemetry data
#  3. Output the splited data to TARGET_FILE_FOLDER
#  4. Bad Files/Bad Records are sent to BAD_RECORDS_PATH
#
#  Please check "Widget for configuration parameters" to understand the parameters used to run this notebook.  
#   
#  Note: 
#    By default Databricks will prevent duplicated data ingestion. If you have same files name for testing purpose, you need to change CheckPoint Location to different locations each time. 
#
# =================================================================

# COMMAND ----------

dbutils.widgets.removeAll()

# COMMAND ----------

# Widget for configuration parameters
# When runing by Databricks Jobs, these parameter will be changed by Databrick jobs (job setting could come from deployment script)
# 
dbutils.widgets.text("secretscope", "secretScope", "secretscope_Label")   # Databricks Secret Scope Name 
dbutils.widgets.text("source_stream_storage_account","tm03landing","source_stream_storage_account_Label")  # Azure Storage Account Name for source(input) files
dbutils.widgets.text("target_file_storage_account","tm03ingestion","target_file_storage_account_Label")    # Azure Storage Account Name for target(output) files
dbutils.widgets.text("source_stream_folder","abfss://data@tm03landing.dfs.core.windows.net/telemetry","source_stream_folder_Label")  # Source files location
dbutils.widgets.text("target_file_folder","abfss://data@tm03ingestion.dfs.core.windows.net/databricks-out","target_file_folder_Label")  # Target files location
dbutils.widgets.text("chekc_point_location","abfss://data@tm03landing.dfs.core.windows.net/checkpoint","chekc_point_location_Label") # Check Point location for Spark Structured Streaming
dbutils.widgets.text("triger_process_time","10 seconds","triger_process_time_Label") # Trigger Process interval for Spark Structured Streaming
dbutils.widgets.text("max_files","30","max_files_Label")  # Max Process files per trigger of Spark Structgured Streaming
dbutils.widgets.text("queue_name_list","landingeventqueue0,landingeventqueue1","queue_name_list_Label") #Queue Name for Spark Cloud files, multiple queues are supported, seperate queue name by comma
dbutils.widgets.text("bad_records_path","abfss://data@tm03landing.dfs.core.windows.net/badrecords","bad_records_path_Label") # Bad Record Path for Spark Structured Streaming
dbutils.widgets.text("shuffle_partitions","64","shuffle_partitions_Label") # Bad Record Path for Spark Structured Streaming

# COMMAND ----------

from pathlib import Path
import json
from pyspark.sql.types import StructType, IntegerType, StringType
import pyspark.sql.functions as F
from ast import literal_eval
from distutils.util import strtobool

# COMMAND ----------

# Configurations 
secretscope=dbutils.widgets.get("secretscope")
SOURCE_FILE_PATH_SECRET=dbutils.secrets.get(secretscope,"source-files-secrets")  # Secret to access Source Files for data preprocessor - BATCH MODE
CREATE_REMOTE_FILE_SYSTEM="true"      
CREATE_REMOTE_FILES_SYSTEM_DURING_INIALIAZATION="false"
OUTPUT_FILE_PATH_SECRET=dbutils.secrets.get(secretscope,"target-files-secrets")  # Secret to access Target Files for data preprocessor - BATCH MODE
TARGET_FILE_FOLDER=dbutils.widgets.get("target_file_folder") # Target Files folder - BATCH MODE : Location to place splited files
CLOUDFILE_CONNECTION_STRING=dbutils.secrets.get(secretscope,"cloud-files-connection-string")
SOURCE_STREAM_FILES_FOLDER=dbutils.widgets.get("source_stream_folder")
CLOUDFILE_QUEUE_NAME=""
CHECK_POINT_LOCATION=dbutils.widgets.get("chekc_point_location")
TRIGER_PROCESS_TIME=dbutils.widgets.get("triger_process_time")
MAX_FILES=int(dbutils.widgets.get("max_files"))
QUEUE_NAME_LIST=dbutils.widgets.get("queue_name_list").split(',')
BAD_RECORDS_PATH=dbutils.widgets.get("bad_records_path")
SHUFFLE_PARTITIONS=int(dbutils.widgets.get("shuffle_partitions"))


# COMMAND ----------

# Set Configuration in Spark Config 
spark.conf.set("fs.azure.account.key.{}.dfs.core.windows.net".format(dbutils.widgets.get("source_stream_storage_account")), SOURCE_FILE_PATH_SECRET)
spark.conf.set("fs.azure.createRemoteFileSystemDuringInitialization", CREATE_REMOTE_FILE_SYSTEM)
spark.conf.set("fs.azure.createRemoteFileSystemDuringInitialization", CREATE_REMOTE_FILES_SYSTEM_DURING_INIALIAZATION)
spark.conf.set("fs.azure.account.key.{}.dfs.core.windows.net".format(dbutils.widgets.get("target_file_storage_account")), OUTPUT_FILE_PATH_SECRET)
spark.conf.set("fs.azure.account.key.{}.dfs.core.windows.net".format(dbutils.widgets.get("target_file_storage_account")), OUTPUT_FILE_PATH_SECRET)
spark.conf.set('spark.sql.shuffle.partitions', SHUFFLE_PARTITIONS)

# COMMAND ----------

# Schema definition of Telemetry data
SCHEMA_DEF='{"fields":[{"metadata":{},"name":"companyId","nullable":true,"type":"string"},{"metadata":{},"name":"complexData","nullable":true,"type":{"fields":[{"metadata":{},"name":"moreData0","nullable":true,"type":"double"},{"metadata":{},"name":"moreData1","nullable":true,"type":"double"},{"metadata":{},"name":"moreData10","nullable":true,"type":"double"},{"metadata":{},"name":"moreData11","nullable":true,"type":"double"},{"metadata":{},"name":"moreData12","nullable":true,"type":"double"},{"metadata":{},"name":"moreData13","nullable":true,"type":"double"},{"metadata":{},"name":"moreData14","nullable":true,"type":"double"},{"metadata":{},"name":"moreData15","nullable":true,"type":"double"},{"metadata":{},"name":"moreData16","nullable":true,"type":"double"},{"metadata":{},"name":"moreData17","nullable":true,"type":"double"},{"metadata":{},"name":"moreData18","nullable":true,"type":"double"},{"metadata":{},"name":"moreData19","nullable":true,"type":"double"},{"metadata":{},"name":"moreData2","nullable":true,"type":"double"},{"metadata":{},"name":"moreData20","nullable":true,"type":"double"},{"metadata":{},"name":"moreData21","nullable":true,"type":"double"},{"metadata":{},"name":"moreData22","nullable":true,"type":"double"},{"metadata":{},"name":"moreData3","nullable":true,"type":"double"},{"metadata":{},"name":"moreData4","nullable":true,"type":"double"},{"metadata":{},"name":"moreData5","nullable":true,"type":"double"},{"metadata":{},"name":"moreData6","nullable":true,"type":"double"},{"metadata":{},"name":"moreData7","nullable":true,"type":"double"},{"metadata":{},"name":"moreData8","nullable":true,"type":"double"},{"metadata":{},"name":"moreData9","nullable":true,"type":"double"}],"type":"struct"}},{"metadata":{},"name":"createdAt","nullable":true,"type":"string"},{"metadata":{},"name":"deviceId","nullable":true,"type":"string"},{"metadata":{},"name":"deviceSequenceNumber","nullable":true,"type":"long"},{"metadata":{},"name":"eventId","nullable":true,"type":"string"},{"metadata":{},"name":"type","nullable":true,"type":"string"},{"metadata":{},"name":"value","nullable":true,"type":"double"}],"type":"struct"}'

# COMMAND ----------

from pyspark.sql.types import IntegerType
from pyspark.sql.functions import udf,pandas_udf,col
from pyspark.sql.functions import *

# Create Structure Streaming tasks for split data 
def split_data_stream_by_size(poolnum, max_file, includeExistingFiles,sdl_schema, cloudfile_connection_string, source_stream_file_folder,queue_name, outputfolder, checkpointlocation, base_archivedir, trigger_process_time='10 seconds' ):
    print(source_stream_file_folder)
    print ("base_archivedir Files {}".format(base_archivedir))
    print ("Begin to run structure streaming with queue {}, max files {}, source files {}, outputfolder {}, check-point location {}, trigger-process-time {}". \
         format(queue_name,max_file,source_stream_file_folder,outputfolder,checkpointlocation,trigger_process_time))
    spark.sparkContext.setLocalProperty("spark.scheduler.pool", "pool-{}-{}".format(queue_name,poolnum))
    file_filter=""  
    dbutils.fs.mkdirs(source_stream_file_folder) #Create folder for Spark structured steaming to read. The SDK will do nothing if the folder already existed
    print("Source files path is {}".format(source_stream_file_folder)) 
 
  #Use Auto-Loader or Folder Listing model
    sdltelemetryDF = (
      spark.readStream \
      .format("cloudFiles") \
      .option("cloudFiles.format", "json") \
      .option("cloudFiles.useNotifications", "true") \
      .option("cloudFiles.queueName",queue_name) \
      .option("cloudFiles.connectionString",cloudfile_connection_string ) \
      .option("cloudFiles.maxFilesPerTrigger", max_file) \
      .option("cloudFiles.includeExistingFiles", includeExistingFiles) \
      .option("badRecordsPath", BAD_RECORDS_PATH) 
      .schema(sdl_schema) \
      .load(source_stream_file_folder))

    # Splite data by Customer Id , PName
    sdlquery=sdltelemetryDF.withColumn("companyIdkey", F.col("companyId")).withColumn("typekey", F.col("type")) \
    .repartition("companyIdkey", "typekey").writeStream.partitionBy("companyIdkey", "typekey") \
    .format("JSON") \
    .outputMode("append") \
    .option('path', outputfolder) \
    .option("checkpointLocation", checkpointlocation) \
    .trigger(processingTime=trigger_process_time) \
    .start()
    return sdlquery
  
# Create Multiple structure streamings for different queues
def split_data_stream_batch( max_file, includeExistingFiles,sdl_schema, cloudfile_connection_string, source_stream_file_folder,queue_name_list, outputfolder, checkpointlocation_base, base_archivedir, trigger_process_time='10 seconds'):
  runs={}
  poolnum=0
  for queue_name in queue_name_list: 
    print ("Trying to run structure streaming with queue {} pool num ".format(queue_name,poolnum))
    run=split_data_stream_by_size(poolnum, max_file, includeExistingFiles,sdl_schema, cloudfile_connection_string, source_stream_file_folder,queue_name, outputfolder+'/'+queue_name, checkpointlocation_base+'/'+queue_name, base_archivedir,trigger_process_time)
    poolnum+=1     
    runs[queue_name]=run
  return runs 


# COMMAND ----------

sdl_schema =  StructType.fromJson(json.loads(SCHEMA_DEF))  # Load Schema from notebook

# COMMAND ----------

# Start the structure streaming Job
runs=split_data_stream_batch(MAX_FILES,True,sdl_schema, CLOUDFILE_CONNECTION_STRING,SOURCE_STREAM_FILES_FOLDER,QUEUE_NAME_LIST,TARGET_FILE_FOLDER,CHECK_POINT_LOCATION,"BASE_ARCHIVE_DIR", TRIGER_PROCESS_TIME)
print(len(runs))

# COMMAND ----------



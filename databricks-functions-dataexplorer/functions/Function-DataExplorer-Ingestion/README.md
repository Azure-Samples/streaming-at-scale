# Azure function of SDL data ingest

## Introduction
This is the Azure function to handle the ingestion management task for ADX

An ADX Ingestion Management is used to help simplify and enhance the ADX “ingestion from storage” pattern when using the ADX python SDK. This module will provide: 

- Applying tag for the data that will be ingested, so it will be easier for data admin to move or drop data.
- use pname dict to get the mapped pname
- Provide each data file’s location and access token to ADX
- Tracking the ingestion status of each individual data file.
- Log the ingestion process into Application Insight.

We used Azure Function to implement above capabilities. Azure Functions is a serverless compute service that lets you run event-triggered code without having to explicitly provision or manage infrastructure.

## Concept

### Azure function
https://docs.microsoft.com/en-us/azure/azure-functions/functions-overview

### Event Grid
https://docs.microsoft.com/en-us/azure/event-grid/overview

### Datalake
https://docs.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction

### Azure data explorer
https://docs.microsoft.com/en-us/azure/data-explorer/data-explorer-overview

## Development
### Azure func tool
Azure Functions Core Tools lets you develop and test your functions on your local computer from the command prompt or terminal. 
https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local?tabs=macos%2Cpython%2Cbash

### Azure Storage
The Azurite version 3.2 open-source emulator (preview) provides a free local environment for testing your Azure blob and queue storage applications.
https://docs.microsoft.com/zh-tw/azure/storage/common/storage-use-azurite


### Test ingest function in local
Install the required tool:
```shell script
bash xdr-search-datalake/azure-functions/tests/local/install_requirement.sh
```

Remove the string "AzureStorageQueuesConnectionString" in function.json manually for local test
Or you will get the error: "Storage account connection string 'AzureStorageQueuesConnectionString' does not exist."

Execute the azure ingest function:
```shell script
bash xdr-search-datalake/azure-functions/tests/local/run_function_local.sh
```

Send trigger event to azure function:
```shell script
# The azure function tool accept the trigger event by format
payload='{"input":"your_triggered_event"}'

# You can send the payload to local url to trigger the event driven function
curl --location --request POST "http://localhost:7071/admin/functions/${function_name}" \
--header 'Content-Type: application/json' \
--data-raw "${payload}"

#Or use script to send the event directly
bash xdr-search-datalake/azure-functions/tests/local/send_local_trigger_event.sh xdr-search-datalake/azure-functions/tests/events/blob_create_event.json
```

## Implementation
1. This code is based on Azure Functions Python Runtime. 
2. It will be triggered by Azure Storage Queue

```python 
def main(msg: func.QueueMessage) -> None:
    logging.info('Python queue trigger function processed a queue item: %s',
                 msg.get_body().decode('utf-8'))
```

3. When it been triggered, it will parse the trigger infomation, get the data time of the data and generate ingestoin meta-data (eg. Data Time) for Azure Data Explorer. 

```python 
    file_time = get_file_time(filepath)

    file_size=FILE_SIZE 
    unpack_file_size_est=file_size*COMPRESS_RATE
 
    dropByTag=filetime.strftime("%Y-%m-%d")
```

4. After the ingestion meta data is prepared, it will call Azure Data Exploere SDK to ingest data from Azure DataLake 

```python 

    KCSB_INGEST = KustoConnectionStringBuilder.with_aad_device_authentication(DATA_INGESTION_URI)
    KCSB_INGEST.authority_id = APP_AAD_TENANT_ID
    
    INGESTION_CLIENT = KustoIngestClient(KCSB_INGEST)

```


5. The ingestion actions are logged in Azure Applicaitn Insights.

```python 

	tc = TelemetryClient(APP_INSIGHT_ID)
	tc.context.application.ver = '1.0'
	tc.context.properties["PROCESS_PROGRAM"]=PROCESS_PROGRAM_NAME
	tc.context.properties["PROCESS_START"]=time.time()    
    tc.context.properties["ingest_source_id"]=ingest_source_id
    tc.track_metric(APP_INSIGHT_INGEST_FILE_SIZE_NAME, file_size)
    tc.track_metric(APP_INSIGHT_INGEST_RECORDS_COUNT_NAME, RECORDS_IN_A_FILE)

    tc.track_event(APP_INSIGHT_INGEST_EVENT_NAME, { 'FILE_PATH': BLOB_PATH,"SOURCE_ID":ingest_source_id }, { 'FILE_SIZE':file_size})

    log_msg="{} Done queuing up ingestion with Azure Data Explorer {}, Ingest SourceID {}".format(LOG_MESSAGE_HEADER,BLOB_PATH,ingest_source_id)
    tc.track_trace(log_msg)
    tc.flush()

```

**Functions Configuration**

The function needs following configurations:


parameter| definition|example 
---|---|---
 AzureWebJobsStorage| Storage account used by Function |DefaultEndpointsProtocol=https;AccountName=xdrsdladxingesteva30func;AccountKey=[ ];EndpointSuffix=core.windows.net
FUNCTIONS_WORKER_RUNTIME| Azure Functions runtime type |python
AzureStorageQueuesConnectionString(connection)| The storage queue Azure Function should monitor |DefaultEndpointsProtocol=https;AccountName=xdrsdlsevalqueue30;AccountKey=[];EndpointSuffix=core.windows.net
FUNCTIONS_EXTENSION_VERSION| Azure Functions version |~3
APPINSIGHTS_INSTRUMENT_KEY| Instrument key for Application Insight |6cf44a28-96c2-4b96????
APPLICATIONINSIGHTS_CONNECTION_STRING|  Instrument connection string for Application Insight  |InstrumentationKey=6cf44a28-96c2-4b96-???
SOURCE_TELEMETRY_BLOB_ACCOUNT| Azure Data Lake storage that stores the gz files from Data Importer |xdrsdladxeval
SOURCE_TELEMETRY_FILE_TOKEN| the SAS key to access Azure Data Lake storage |?sv=2019-02-02&ss=b&srt=sco&sp=rl&se=2040-04-16T16|49|51Z&st=2020-04-16T08|49|51Z&spr=https&sig=????
PROCESSED_TELEMETRY_FOLDER| folder in Azure data lake where gz files from data importor stored |
APP_AAD_TENANT_ID| the service principal tenant ID that can access Azure Data Explorer |3e04753a-ae5b-???
APP_CLIENT_ID| the service principal ID that can access Azure Data Explorer |dfdd4a10-c47f-???
APP_CLIENT_SECRETS| the service principal secrets that can access Azure Data Explorer |
INGESTION_SERVER_URI| The ADX Ingestion Server URL |https://ingest-XXXX.eastus2.kusto.windows.net:443
DATABASE| the ADX database to ingest telemetries data |XDR-SDL
DESTINATION_TABLE| the ADX table to ingest telemetries data |sdltelemetry_raw
INGESTION_MAPPING|the ADX ingestion mapping when ingesting data  into ADX table  |sdl_json_mapping_01
APP_INSIGHT_MAIN_ERROR_EVENT_NAME| Error Log event name in Application Insights |SDL_ADX_INGEST_ERROR
APP_INSIGHT_INGEST_SUCCESS_COUNT_NAME|Success Count Metric name in Application Insights |SDL_ADX_INGEST_SUCCESS_COUNT
APP_INSIGHT_INGEST_FAILURE_COUNT_NAME| Failure Count Metric name in Application Insights  |SDL_ADX_INGEST_FAILURE_COUNT
APP_INSIGHT_INGEST_SUCCESS_EVENT_NAME|  Success ingestion event name in Application Insights |SDL_ADX_INGEST_JSON_SUCCESS
APP_INSIGHT_INGEST_FAILURE_EVENT_NAME| Failed ingestion event name in Application Insights |SDL_ADX_INGEST_JSON_FAILURE
SUCCESS_STATUS|Success ingestion status name in Application Insights |SUCCESS
FAILURE_STATUS| Failed  ingestion status name in Application Insights |FAILURE
IS_FLUSH_IMMEDIATELY|Is data should ingest into ADX right away, since this will impact system performance, __only set True when you are testing a small volumnes of data__.  |False
LOG_MESSAGE_HEADER| Trace Log message Header in Application Insights |[XDR-SDL-ADX-INJESTION]
PROCESS_PROGRAM_NAME|  Programe name logged  in Application Insights |xdrsdladxingect_V001a
EVENT_SUBJECT_FILTER_REGEX| Regular Express that are used to filter files, only file name matched the regular expression will be processed  |shardId(.*?)[0-9].gz
ENABLE_ORYX_BUILD| defualt parameter created by Azure Funtions core tools |true
SCM_DO_BUILD_DURING_DEPLOYMENT| defualt parameter created by Azure Funtions core tools  |1
BUILD_FLAGS|defualt parameter created by Azure Funtions core tools  |UseExpressBuild
XDG_CACHE_HOME| defualt parameter created by Azure Funtions core tools  |/tmp/.cache
FUNCTIONS_WORKER_PROCESS_COUNT|Max worker process numbers |10
FILE_SIZE| file size of the telemetry gz file |4194487
COMRESS_RATE| compress rate of the telemtry gz file |5.5
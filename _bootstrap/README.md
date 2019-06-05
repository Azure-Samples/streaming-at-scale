# Boostrap Solution

This folder and its content can be used as a starting point to create a new end-to-end streaming solution sample. Followingyou can find the instruction to collaborate by creating new end-to-end samples.

## Create a new folder

Create a new folder, following the established naming convention:

```text
<ingestion-technology>-<stream-processor-technology>-<serving-technology>
```

for example:

```text
kafka-databricks-cosmos
```

if you're planning to create an end-to-end solution using Kafka as the ingestion technology, the Databricks Spark to do the stream processing, and then Cosmos DB to store and serve the results of processed data.

Copy the content of this `_bootstrap` folder into the folder you just created.

## Folder content

### create-solution.sh

`create-solution.sh` is the script that the end user will execute to deploy the end-to-end solution. Take a look at it and change it to make sure it references the correct file. Section that you're likely to change are delimited with `BEGIN` and `END` comments.

The file does the following things:

* gets and validates the argument
* make sure required software are available
* exports the variables used in called scripts
* set correct values for 1, 5 and 10 msgs/sec test
* execute the requested step by executing the related scripts 

Code should be self-explanatory; if not, just ask.

### 01-create-event-hub.sh

`01-create-event-hub.sh`: this files creates the Event Hub used for ingestion. If you are planning to use some other technology for the ingestion phase, like Kafka, just remove this file and create a new one, with a new name, that suits your need. Try to follow the same coding style to make sure samples are consistent.

 If you are using Event Hub, you almost surely can use this script as is, without any change.

### 02-create-database.sh

`02-create-database.sh`: this files is empty, as you have to fill in with the code needed to deploy the database you want to use for the end-to-end sample. You can take a look at the following script to understand how you can create your:

* [eventhubs-streamanalytics-azuresql/02-create-azure-sql.sh](../eventhubs-streamanalytics-azuresql/02-create-azure-sql.sh)
* [eventhubs-streamanalytics-cosmosdb/02-create-cosmosdb.sh](../eventhubs-streamanalytics-cosmosdb/02-create-cosmosdb.sh)

once you have created your file, make sure you rename it so that it will be clear which technology is using.

### 03-create-stream-processor.sh

`03-create-stream-processor.sh`: this files is empty, just like for the previous file, as you have to fill in with the code needed to deploy the stream processor you want to use for the end-to-end sample. You can take a look at the following script to understand how you can create your:

* [eventhubs-functions-cosmosdb/03-create-processing-function.sh](../eventhubs-functions-cosmosdb/03-create-processing-function.sh)
* [eventhubs-streamanalytics-azuresql/03-create-stream-analytics.sh](../eventhubs-streamanalytics-azuresql/03-create-stream-analytics.sh)

once you have created your file, make sure you rename it so that it will be clear which technology is using.

### 04-run-clients.sh

`04-run-clients.sh` contains the code need to setup a [Locust](http://locust.io) cluster in distributed mode, usiong Azure Container Instances.

Each locust generates up to 340 msgs/sec. Each generated message is close to 1KB and look like this:

```json
{
    "eventId": "b81d241f-5187-40b0-ab2a-940faf9757c0",
    "complexData": {
        "moreData0": 12.12345678901234,
        "moreData1": 12.12345678901234,
        "moreData2": 12.12345678901234,
        "moreData3": 12.12345678901234,
        "moreData4": 12.12345678901234,
        "moreData5": 12.12345678901234,
        "moreData6": 12.12345678901234,
        "moreData7": 12.12345678901234,
        "moreData8": 12.12345678901234,
        "moreData9": 12.12345678901234,
        "moreData10": 12.12345678901234,
        "moreData11": 12.12345678901234,
        "moreData12": 12.12345678901234,
        "moreData13": 12.12345678901234,
        "moreData14": 12.12345678901234,
        "moreData15": 12.12345678901234,
        "moreData16": 12.12345678901234,
        "moreData17": 12.12345678901234,
        "moreData18": 12.12345678901234,
        "moreData19": 12.12345678901234,
        "moreData20": 12.12345678901234,
        "moreData21": 12.12345678901234,
        "moreData22": 12.12345678901234
    },
    "value": 49.02278128887753,
    "deviceId": "contoso://device-id-1554",
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```

and it will send data to the specified Event Hub. If you need to send data to something different, then you will need to create a new locustfile in [../_common/locust/simulator.py]([../_common/locust/simulator.py) and also make sure it is uploaded to the shared file folder (check the code in the script)

## General Notes

Nothing is written in stone so if you need more than four files, just add the files you need and change the script accordingly. This has been done, for example, here:

[eventhubs-functions-cosmosdb](../eventhubs-functions-cosmosdb/)

In general you can take a look at the following samples

* [eventhubs-functions-cosmosdb](../eventhubs-functions-cosmosdb/)
* [eventhubs-streamanalytics-azuresql](../eventhubs-streamanalytics-azuresql/)
* [eventhubs-streamanalytics-cosmosdb](../eventhubs-streamanalytics-cosmosdb/)

to have an idea of what you can do...which is everything needed to make sure you sample work, just try to be consistent with existing code, so that end user doesn't have the navigate through different coding style and conventions.


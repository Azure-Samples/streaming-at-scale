# Boostrap Solution

This folder and its content can be used as a starting point to create a new end-to-end streaming solution sample. Following you can find the instruction to collaborate by creating new end-to-end samples.

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

## Script content

### create-solution.sh

`create-solution.sh` is the script that the end user will execute to deploy the end-to-end solution. Take a look at it and change it to make sure it references the correct file. Section that you're likely to change are delimited with `BEGIN` and `END` comments.

The file does the following things:

* gets and validates the argument
* make sure required software are available
* exports the variables used in called scripts
* set correct values for 1, 5 and 10 msgs/sec test
* execute the requested step by executing the related scripts 

Code should be self-explanatory; if not, just ask.

### source ../components/azure-event-hubs/create-event-hub.sh

`create-event-hub.sh`: this script creates the Event Hub used for ingestion. If you are planning to use some other technology for the ingestion phase, like Kafka, just use another component or create a new one, with a new name, that suits your need. Try to follow the same coding style to make sure samples are consistent.

 If you are using Event Hub, you almost surely can use this script as is, without any change.

### source ../components/azure-cosmosdb/create-cosmosdb.sh

`create-cosmosdb.sh`: this script creates a Cosmos DB instance for serving, again you can use another component instead, such as azure-sql.

* [../components/azure-sql/create-sql.sh](../components/azure-sql/create-sql.sh)

once you have created your file, make sure you rename it so that it will be clear which technology is using.

### source ../components/azure-functions/create-processing-function.sh
### source ../components/azure-functions/configure-processing-function-cosmosdb.sh

`create-processing-function.sh`: this script creates an Azure Function for stream processing, again you can use another component instead, such as Databricks, or provide your own script.

`configure-processing-function-cosmosdb.sh`: this script configures the Azure Function for output to Cosmos DB, here too you can change to another variant, e.g. to output to Azure SQL.

You can take a look at the following script to understand how you can create your:

* [eventhubs-streamanalytics-azuresql/create-stream-analytics.sh](../eventhubs-streamanalytics-azuresql/create-stream-analytics.sh)

once you have created your file, make sure you rename it so that it will be clear which technology is using.

### source ../simulator/run-generator-eventhubs.sh

`run-generator-eventhubs.sh` contains the code need to setup Spark clients, using Azure Container Instances.

Each client generates up to 2000 msgs/sec. Each generated message is close to 1KB and look like this:

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

and it will send data to the specified Event Hub.

### source ../components/azure-event-hubs/report-throughput.sh

`report-throughput.sh` queries Azure Monitor for Event Hub metrics and reports incoming and outgoing messages per minute. Ideally after a ramp-up phase those two metrics should be similar.

## General Notes

Nothing is set in stone so if you need more than four files, just add the files you need and change the script accordingly. This has been done, for example, here:

[eventhubs-functions-cosmosdb](../eventhubs-functions-cosmosdb/)

In general you can take a look at the following samples

* [eventhubs-functions-cosmosdb](../eventhubs-functions-cosmosdb/)
* [eventhubs-streamanalytics-azuresql](../eventhubs-streamanalytics-azuresql/)
* [eventhubs-streamanalytics-cosmosdb](../eventhubs-streamanalytics-cosmosdb/)

to have an idea of what you can do...which is everything needed to make sure you sample work, just try to be consistent with existing code, so that end user doesn't have the navigate through different coding style and conventions.


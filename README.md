---
page_type: sample
languages:
  - azurecli
  - csharp
  - json
  - sql
  - scala
products:
  - azure
  - azure-container-instances
  - azure-cosmos-db
  - azure-databricks
  - azure-data-explorer
  - azure-event-hubs
  - azure-functions  
  - azure-kubernetes-service
  - azure-sql-database
  - azure-stream-analytics
  - azure-storage
  - azure-time-series-insights
statusNotificationTargets:
  - algattik@microsoft.com
description: "How to setup an end-to-end solution to implement a streaming at scale scenario using a choice of different Azure technologies."
---

# Streaming at Scale

The samples shows how to setup an end-to-end solution to implement a streaming at scale scenario using a choice of different Azure technologies. There are *many* possible way to implement such solution in Azure, following [Kappa](https://milinda.pathirage.org/kappa-architecture.com/) or [Lambda](http://lambda-architecture.net/) architectures, a variation of them, or even custom ones. Each architectural solution can also be implemented with different technologies, each one with its own pros and cons.

More info on Streaming architectures can also be found here:

- [Big Data Architectures](https://docs.microsoft.com/en-us/azure/architecture/data-guide/big-data): notes on Kappa, Lambda and IoT streaming architectures
- [Real Time Processing](https://docs.microsoft.com/en-us/azure/architecture/data-guide/big-data/real-time-processing): details on real-time processing architectures

Here's also a list of scenarios where a Streaming solution fits nicely

- [Event-Driven](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/event-driven)
- [CQRS](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs)
- [Microservices](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/microservices)
- [Big Data](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/big-data)
- [Near-Real Time Operational Analytics](https://docs.microsoft.com/en-us/sql/relational-databases/indexes/get-started-with-columnstore-for-real-time-operational-analytics?view=sql-server-2017)

A good document the describes the Stream *Technologies* available on Azure is the following one:

[Choosing a stream processing technology in Azure](https://docs.microsoft.com/en-us/azure/architecture/data-guide/technology-choices/stream-processing)

The goal of this repository is to showcase all the possible common architectural solution and implementation, describe the pros and the cons and provide you with sample script to deploy the whole solution with 100% automation.

## Running the samples

Please note that the scripts have been tested on [Ubuntu 18 LTS](http://releases.ubuntu.com/18.04/), so make sure to use that environment to run the scripts. You can run it using Docker, WSL or a VM:

- [Ubuntu Docker Image](https://hub.docker.com/_/ubuntu/)
- [Windows 10 WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10)
- [WSL Ubuntu 18.04 LTS](https://www.microsoft.com/en-us/p/ubuntu-1804-lts/9n9tngvndl3q?activetab=pivot:overviewtab)
- [Ubuntu 18.04 LTS Azure VM](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/Canonical.UbuntuServer1804LTS)

Just do a `git clone` of the repo and you'll be good to go.

Each sample may have additional requirements: they will be listed in the sample's README.

## Streamed Data

Streamed data simulates an IoT device sending the following JSON data:

```json
{
    "eventId": "b81d241f-5187-40b0-ab2a-940faf9757c0",
    "complexData": {
        "moreData0": 57.739726013343247,
        "moreData1": 52.230732688620829,
        "moreData2": 57.497518587807189,
        "moreData3": 81.32211656749469,
        "moreData4": 54.412361539409427,
        "moreData5": 75.36416309399911,
        "moreData6": 71.53407865773488,
        "moreData7": 45.34076957651598,
        "moreData8": 51.3068118685458,
        "moreData9": 44.44672606436184,
        [...]
    },
    "value": 49.02278128887753,
    "deviceId": "contoso://device-id-154",
    "deviceSequenceNumber": 0,
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```

## Duplicate event handling

Event delivery guarantees are a critical aspect of streaming solutions. Azure Event Hubs provides an at-least-once event delivery guarantees. In addition, the upstream components that compose a real-world deployment will typically send events to Event Hubs with at-least-once guarantees (i.e. for reliability purposes, they should be configured to retry if they do not get an acknowledgement of message reception by the Event Hub endpoint, though the message might actually have been ingested). And finally, the stream processing system typically only has at-least-once guarantees when delivering data into the serving layer. Duplicate messages are therefore unavoidable and are better dealt with explicitly.

Depending on the type of application, it might be acceptable to store and serve duplicate messages, or it might desirable to deduplicate messages. The serving layer might even have strong uniqueness guarantees (e.g. unique key in Azure SQL Database). To demonstrate effective message duplicate handling strategies, the various solution templates demonstrate, where possible, effective message duplicate handling strategies for the given combination of stream processing and serving technologies. In most solutions, the event simulator is configured to randomly duplicate a small fraction of the messages (0.1% on average).

## Integration tests

End-to-end integration tests are configured to run. You can check the [latest closed pulled requests](https://github.com/Azure-Samples/streaming-at-scale/pulls?q=is%3Aclosed) ("View Details") to navigate to the integration test run in Azure DevOps. The integration test suite deploys each solution and runs verification jobs in Azure Databricks that pull the data from the serving layer of the given solution and verifies the solution event processing rate and duplicate handling guarantees.

## Available solutions

At present time the available solutions are

### [Kafka on AKS + Azure Databricks + Cosmos DB](akskafka-databricks-cosmosdb)

Implement a stream processing architecture using:

- Kafka on Azure Kubernetes Service (AKS) (Ingest / Immutable Log)
- Azure Databricks (Stream Process)
- Cosmos DB (Serve)

### [Event Hubs Capture Sample](eventhubs-capture)

Implement stream processing architecture using:

- Event Hubs (Ingest)
- Event Hubs Capture (Store)
- Azure Blob Store (Data Lake)
- Apache Drill (Query/Serve)

### [Event Hubs + Azure Databricks + Azure SQL](eventhubs-databricks-azuresql)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Azure Databricks (Stream Process)
- Azure SQL (Serve)

### [Event Hubs + Azure Databricks + Cosmos DB](eventhubs-databricks-cosmosdb)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Azure Databricks (Stream Process)
- Cosmos DB (Serve)

### [Event Hubs Kafka + Azure Databricks + Cosmos DB](eventhubskafka-databricks-cosmosdb)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log) with Kafka endpoint
- Azure Databricks (Stream Process)
- Cosmos DB (Serve)

### [Event Hubs + Azure Databricks + Delta](eventhubs-databricks-delta)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Azure Databricks (Stream Process)
- [Delta Tables](https://delta.io/) (Serve)

### [Event Hubs + Azure Functions + Azure SQL](eventhubs-functions-azuresql)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Azure Functions (Stream Process)
- Azure SQL (Serve)

### [Event Hubs + Azure Functions + Cosmos DB](eventhubs-functions-cosmosdb)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Azure Functions (Stream Process)
- Cosmos DB (Serve)

### [Event Hubs + Stream Analytics + Cosmos DB](eventhubs-streamanalytics-cosmosdb)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Stream Analytics (Stream Process)
- Cosmos DB (Serve)

### [Event Hubs + Stream Analytics + Azure SQL](eventhubs-streamanalytics-azuresql)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Stream Analytics (Stream Process)
- Azure SQL (Serve)

### [Event Hubs + Stream Analytics + Event Hubs](eventhubs-streamanalytics-eventhubs)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Stream Analytics (Stream Process)
- Event Hubs (Serve)

### [HDInsight Kafka + Azure Databricks + Azure SQL](hdinsightkafka-databricks-sqldw)

Implement a stream processing architecture using:

- HDInsight Kafka (Ingest / Immutable Log)
- Azure Databricks (Stream Process)
- Azure SQL Data Warehouse (Serve)

### [Event Hubs + Azure Data Explorer](eventhubs-dataexplorer)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Azure Data Explorer (Stream Process / Serve)

### [Event Hubs + Data Accelerator + Cosmos DB](eventhubs-dataaccelerator-cosmosdb)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Microsoft Data Accelerator on HDInsight and Service Fabric (Stream Process)
- Cosmos DB (Serve)

### [Event Hubs + Time Series Insights](eventhubs-timeseriesinsights)

Implement a stream processing architecture using:

- Event Hubs (Ingest / Immutable Log)
- Time Series Insights (Stream Process / Serve / Store to Parquet)
- Azure Storage (Serve for data analytics)

## Note

Performance and Services change quickly in the cloud, so please keep in mind that all values used in the samples were tested at them moment of writing. If you find any discrepancies with what you observe when running the scripts, please create an issue and report it and/or create a PR to update the documentation and the sample. Thanks!

## Roadmap

The following technologies could also be used in the end-to-end sample solution. If you want to contribute, feel free to do so, we'll be more than happy to get some help!

### Ingestion

- IoT Hub

### Stream Processing

### Batch Processing

### Serving Layer

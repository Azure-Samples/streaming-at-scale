# Streaming at Scale

Sample end-to-end solutions to implement streaming at scale scenarios using Azure

## About the repository

The sample shows how to setup an end-to-end solution to implement a streaming at scale scenario using a choice of different Azure technologies. There are *many* possible way to implement such solution in Azure, following [Kappa](https://milinda.pathirage.org/kappa-architecture.com/) or [Lambda](http://lambda-architecture.net/) architectures, a variation of them, or even custom ones. Each architectural solution can also be implemented with different technologies, each one with its own pros and cons.

More info on Streaming architectures can also be found here:

- [Big Data Architectures](https://docs.microsoft.com/en-us/azure/architecture/data-guide/big-data): notes on Kappa, Lambda and IoT streaming architectures
- [Real Time Processing](https://docs.microsoft.com/en-us/azure/architecture/data-guide/big-data/real-time-processing): details on real-time processing architectures

Here's also a list of scenarios where a Streaming solution fits nicely

- [Event-Driven](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/event-driven)
- [CQRS](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/cqrs)
- [Microservices](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/microservices)
- [Big Data](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/big-data)
- Near-Real Time Operational Analytics

A good document the describes the Stream *Technologies* available on Azure is the following one:

[Choosing a stream processing technology in Azure](https://docs.microsoft.com/en-us/azure/architecture/data-guide/technology-choices/stream-processing)

The goal of this repository is to showcase all the possible common architectural solution and implementation, describe the pros and the cons and provide you with sample script to deploy the whole solution with 100% automation.

## Running the samples

All samples uses AZ CLI and Bash scripts. Make sure you have AZ CLI installed:

https://docs.microsoft.com/en-us/cli/azure/?view=azure-cli-latest 

If you're running on Windows, it is suggested to run script from WSL

https://docs.microsoft.com/en-us/windows/wsl/install-win10

although you can also run them from any Bash environment. Just keep in mind that script have been tested on Ubuntu on WSL and OS X only.

In order to clone the repository you'll also need Git:

https://git-scm.com/downloads

The Git For Windows version comes with a Bash too

https://gitforwindows.org/

Some samples may have more specific needs. In that case the required software will be mentioned in sample's readme.

## Available solutions

At present time the available solutions are

[Event Hubs Capture Sample](eventhubs-capture)

Implement stream processing architecture using:
- Event Hubs (Ingest)
- Event Hubs Capture (Store)
- Azure Blob Store (Data Lake)
- Apache Drill (Query/Serve)

[Event Hubs + Azure Functions + Cosmos DB](eventhubs-functions-cosmosdb)

Implement a stream processing architecture using:
- Event Hubs (Ingest / Immutable Log)
- Azure Functions (Stream Process)
- Cosmos DB (Serve)

[Event Hubs + Stream Analytics + Cosmos DB](eventhubs-functions-cosmosdb)

Implement a stream processing architecture using:
- Event Hubs (Ingest / Immutable Log)
- Stream Analytics (Stream Process)
- Cosmos DB (Serve)

[Event Hubs + Stream Analytics + Cosmos DB](eventhubs-functions-azuresql)

Implement a stream processing architecture using:
- Event Hubs (Ingest / Immutable Log)
- Stream Analytics (Stream Process)
- Azure SQL (Serve)

[Event Hubs + Stream Analytics + Cosmos DB](eventhubs-functions-eventhubs)

Implement a stream processing architecture using:
- Event Hubs (Ingest / Immutable Log)
- Stream Analytics (Stream Process)
- Event Hubs (Serve)

## Roadmap

The following technologies are planned to be used in the end-to-end sample solution

### Ingestion

- IoT Hub 
- EventHub Kafka

### Stream Processing

- Databricks Spark Structured Streaming
- Azure Data Explorer

### Batch Processing

- EventHubs Capture
- Databricks Spark
- Azure Data Explorer
- Open Source solutions (like Apache Drill)

### Serving Layer

- Azure Data Explorer
- Azure DW

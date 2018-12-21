# Streaming at Scale
Sample end-to-end solutions to implement streaming at scale scenarios using Azure

## About the repo
The sample shows how to setup an end-to-end solution to implement a streaming at scale scenario using a choice of different Azure technologies. There are *many* possible way to implement such solution in Azure, following [Kappa](https://milinda.pathirage.org/kappa-architecture.com/) or [Lambda](http://lambda-architecture.net/) architetures, a variation of them, or even custom ones. Each architectural soution can also be implemented with different technologies, each one with its own pros and cons. 

More info on Streaming architectures can also be found here:

- [Big Data Architectures](https://docs.microsoft.com/en-us/azure/architecture/data-guide/big-data): notes on Kappa, Lambda and IoT streaming architectures
- [Real Time Processing](https://docs.microsoft.com/en-us/azure/architecture/data-guide/big-data/real-time-processing): details on real-time processings architectures

Here's also a list of scenarios where a Streaming solution fits nicely

- [Event-Driven](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/event-driven)
- [CQRS](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/cqrs)
- [Microservices](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/microservices)
- [Big Data](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/big-data)
- Near-Real Time Operational Analytics

A good document the describes the Stream *Technologies* available on Azure is the following one:

[Choosing a stream processing technology in Azure](https://docs.microsoft.com/en-us/azure/architecture/data-guide/technology-choices/stream-processing)


The goal of this repo is to showcase all the possibile common architectural solution and implementation, describe the pros and the cons and provide you with sample script to deploy the whole solution with 100% automation.

## Available solutions
At present time the available solutions is

[Cosmos DB Sample](cosmos-db) 

Implement a Kappa architecture using:
- EventHubs (Ingest / Immutable Log)
- AzureFunctions (Stream Process)
- Cosmos DB (Serve)

[EventHubs Capture Sample](event-hubs-capture) 

Implement an Near-Real Time Operational Analytics architecture using:
- EventHubs (Ingest)
- EventHubs Capture (Store)
- Azure Blob Store (Data Lake)
- Apache Drill (Query/Serve)

## Roadmap

The following technologies are planned to be used in the end-to-end sample solution

### Ingestion
- IoT Hub (Work in Progress)
- EventHub Kafka

### Stream Processing
- Databricks Spark Structured Streaming
- Azure Stream Analytics
- HDInsight Apache Storm

### Batch Processing
- EventHubs Capture
- Databricks Spark
- HDInsight
- Open Source solutions (like Apache Drill)

### Serving Layer
- Azure SQL
- Azure DW




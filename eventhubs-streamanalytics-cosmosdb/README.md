# Streaming at Scale with Azure Event Hubs, Stream Analytics and Cosmos DB

This sample uses Stream Analytics to process streaming data from EventHub and uses Cosmos DB as a sink to store JSON data

The provided scripts will create an end-to-end solution complete with load test client.  

## Running the Scripts

Please note that the scripts have been tested on [Ubuntu 18 LTS](http://releases.ubuntu.com/18.04/), so make sure to use that environment to run the scripts. You can run it using Docker, WSL or a VM:

- [Ubuntu Docker Image](https://hub.docker.com/_/ubuntu/)
- [WSL Ubuntu 18.04 LTS](https://www.microsoft.com/en-us/p/ubuntu-1804-lts/9n9tngvndl3q?activetab=pivot:overviewtab)
- [Ubuntu 18.04 LTS Azure VM](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/Canonical.UbuntuServer1804LTS)

The following tools/languages are also needed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)
  - Install: `sudo apt install azure-cli`
- [jq](https://stedolan.github.io/jq/)
  - Install: `sudo apt install jq`

## Setup Solution

Make sure you are logged into your Azure account:

    az login

and also make sure you have the subscription you want to use selected

    az account list

if you want to select a specific subscription use the following command

    az account set --subscription <subscription_name>

once you have selected the subscription you want to use just execute the following command

    ./create-solution.sh <solution_name>

then `solution_name` value will be used to create a resource group that will contain all resources created by the script. It will also be used as a prefix for all resource create so, in order to help to avoid name duplicates that will break the script, you may want to generated a name using a unique prefix. **Please also use only lowercase letters and numbers only**, since the `solution_name` is also used to create a storage account, which has several constraints on characters usage:

[Storage Naming Conventions and Limits](https://docs.microsoft.com/en-us/azure/architecture/best-practices/naming-conventions#storage)

**Note**
To make sure that name collisions will be unlikely, you should use a random string to give name to your solution. The following script will generated a 7 random lowercase letter name for you:

    ./generate-solution-name.sh

## Created resources

The script will create the following resources:

* **Azure Container Instances** to host [Locust](https://locust.io/) Load Test Clients: by default two Locust client will be created, generating a load of 1000 events/second
* **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clients
* **Stream Analytics**: to process analytics on streaming data
* **Cosmos DB** Server, Database and Collection: to store and serve processed data

## Solution customization

If you want to change some setting of the solution, like number of load test clients, Cosmos DB RU and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_STREAMING_UNITS=6
    export COSMOSDB_RU=10000
    export TEST_CLIENTS=2

The above settings has been chosen to sustain a 1000 msg/sec stream.
Likewise, below settings has been chosen to sustain at least 10,000 msg/sec stream. 
Each input event is about 1KB, so this translates to 10MB/sec throughput or higher.

    export EVENTHUB_PARTITIONS=16
    export EVENTHUB_CAPACITY=12
    export PROC_STREAMING_UNITS=48
    export COSMOSDB_RU=80000
    export TEST_CLIENTS=20

## Monitor performances

Please use Metrics pane in Stream Analytics for "Input/Output Events", "Watermark Delay" and "Backlogged Input Events" metrics.
The default metrics are aggregated per minute, here is a sample metrics snapshot showing 10K Events/Sec (600K+ Events/minute).
Ensure that "Watermark delay" metric stays in single digit seconds latency.

ASA metrics showing 10K events/sec:

![ASA metrics](.\01-stream-analytics-metrics.png "Azure Stream Analytics 10K events/sec metrics")

You can also use Event Hub "Metrics" pane and ensure there "Throttled Requests" don't slow down your pipeline.

However, In Cosmos DB throttling is expected especially at higher throughput scenarios. 
As long as ASA metric "Watermark delay" is not consistently increasing, your processing is not falling behind, throttling in Cosmos DB is okay.

![Cosmos DB metrics](.\02-cosmosdb-metrics.png "Cosmos DB collection metrics")


## Stream Analytics

Note that the solution configurations have been verified with compatibility level 1.2 . 

The deployed Stream Analytics solution doesn't do any analytics or projection , these will be added as separate solutions.

## Query Data

Data is available in the created Cosmos DB database. You can query it from the portal, for example:

    `SELECT * FROM c WHERE c.eventData.type = 'CO2'`

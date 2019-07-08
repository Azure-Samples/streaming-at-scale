---
topic: sample
languages:
  - azurecli
  - json
  - sql
products:
  - azure
  - azure-container-instances
  - azure-cosmos-db
  - azure-event-hubs
  - azure-stream-analytics
statusNotificationTargets:
  - damauri@microsoft.com
---

# Streaming at Scale with Azure Event Hubs, Stream Analytics and Cosmos DB

This sample uses Stream Analytics to process streaming data from EventHub and uses Cosmos DB as a sink to store JSON data.

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

    ./create-solution.sh -d <solution_name>

then `solution_name` value will be used to create a resource group that will contain all resources created by the script. It will also be used as a prefix for all resource create so, in order to help to avoid name duplicates that will break the script, you may want to generated a name using a unique prefix. **Please also use only lowercase letters and numbers only**, since the `solution_name` is also used to create a storage account, which has several constraints on characters usage:

[Storage Naming Conventions and Limits](https://docs.microsoft.com/en-us/azure/architecture/best-practices/naming-conventions#storage)

to have an overview of all the supported arguments just run

    ./create-solution.sh

**Note**
To make sure that name collisions will be unlikely, you should use a random string to give name to your solution. The following script will generated a 7 random lowercase letter name for you:

    ./generate-solution-name.sh

## Created resources

The script will create the following resources:

- **Azure Container Instances** to host [Locust](https://locust.io/) Load Test Clients: by default two Locust client will be created, generating a load of 1000 events/second
- **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clients
- **Stream Analytics**: to process analytics on streaming data
- **Cosmos DB** Server, Database and Collection: to store and serve processed data

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
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```

## Solution customization

If you want to change some setting of the solution, like number of load test clients, Cosmos DB RU and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_STREAMING_UNITS=6
    export COSMOSDB_RU=20000
    export TEST_CLIENTS=3

The above settings has been chosen to sustain a 1000 msg/sec stream. Likewise, below settings has been chosen to sustain at least 10,000 msg/sec stream. Each input event is about 1KB, so this translates to 10MB/sec throughput or higher.

    export EVENTHUB_PARTITIONS=12
    export EVENTHUB_CAPACITY=12
    export PROC_STREAMING_UNITS=36
    export COSMOSDB_RU=100000
    export TEST_CLIENTS=30

## Monitor performances

Please use Metrics pane in Stream Analytics for "Input/Output Events", "Watermark Delay" and "Backlogged Input Events" metrics. The default metrics are aggregated per minute, here is a sample metrics snapshot showing 10K Events/Sec (600K+ Events/minute). Ensure that "Watermark delay" metric stays in single digit seconds latency. "Watermark Delay" is one of the key metric that will help you to understand if Stream Analytics is keeping up with the incoming data. If delay is constantly increasing, you need to take a look at the destination to see if it can keep up with the speed or check if you need to increase SU: https://azure.microsoft.com/en-us/blog/new-metric-in-azure-stream-analytics-tracks-latency-of-your-streaming-pipeline/.

ASA metrics showing 10K events/sec:

![ASA metrics](.\01-stream-analytics-metrics.png "Azure Stream Analytics 10K events/sec metrics")

You can also use Event Hub "Metrics" pane and ensure there "Throttled Requests" don't slow down your pipeline.

However, In Cosmos DB throttling is expected especially at higher throughput scenarios. As long as ASA metric "Watermark delay" is not consistently increasing, your processing is not falling behind, throttling in Cosmos DB is okay.

![Cosmos DB metrics](.\02-cosmosdb-metrics.png "Cosmos DB collection metrics")

## Stream Analytics

Note that the solution configurations have been verified with compatibility level 1.2. The deployed Stream Analytics solution doesn't do any analytics or projection, but it just inject an additional field using a simple Javascript UDF:

```sql
select 
    *, 
    UDF.GetCurrentDateTime('') AS ASAProcessedUtcTime
from 
    inputEventHub partition by PartitionId
```

## Query Data

Data is available in the created Cosmos DB database. You can query it from the portal, for example:

```sql
    SELECT * FROM c WHERE c.type = 'CO2'
```

## Clean up

To remove all the created resource, you can just delete the related resource group

```bash
az group delete -n <resource-group-name>
```

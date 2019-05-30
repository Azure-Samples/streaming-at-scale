# Streaming at Scale with Azure Event Hubs, Stream Analytics and Azure SQL

This sample uses Stream Analytics to process streaming data from EventHub and uses Azure SQL as a sink to store processed data. This is especially useful when you need to create a *Near-Real Time Operational Analytics*, where streaming data has to be ingested at scale and, at the same time, also queried to execute analytical queries. The ability to ingest data into a columnstore is vital to have expected query performances:

[Get started with Columnstore for real time operational analytics](https://docs.microsoft.com/en-us/sql/relational-databases/indexes/get-started-with-columnstore-for-real-time-operational-analytics?view=sql-server-2017)

The provided scripts will create an end-to-end solution complete with load test client.  

## Purpose of this solution

Provide a complete, end-to-end, balanced baseline and starting point for creating a stream processing solution. Everything is done in the simplest and easiest way possible so that you can use it to build up your custom solution.

For example if you know you have to process 5000 messages per second, you can start using the provided configuration option that will make sure you can reach that performances. Once you are confident you can start to add your own business logic that will likely increase the resource usage, depending on how much complex the business logic is, but at least you have a consistent and solid starting point that helps to significantly reduce development and testing times.

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

    ../_common/generate-solution-name.sh

## Created resources

The script will create the following resources:

- **Azure Container Instances** to host [Locust](https://locust.io/) Load Test Clients: by default four Locust nodes (master + 3 slaves) will be created, generating a load of 1000 events/second
- **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clients
- **Stream Analytics** to process analytics on streaming data
- **Azure SQL** Server and Database: to store and serve processed data

## Solution customization

If you want to change some setting of the solution, like number of load test clients, Azure SQL SKU and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

```bash
export EVENTHUB_PARTITIONS=2
export EVENTHUB_CAPACITY=2
export PROC_JOB_NAME=streamingjob
export PROC_STREAMING_UNITS=3 # must be 1, 3, 6 or a multiple or 6
export SQL_SKU=S3
export SQL_TABLE_KIND="rowstore" # or "columnstore"
export TEST_CLIENTS=3
```

The above settings has been chosen to sustain a 1000 msg/sec stream.

## Scaling the solution

In the `create-solution.sh` script values to test

- 1000 msgs/sec
- 5500 msgs/sec
- 10000 msgs/sec

are already set, just uncomment what you what to test, and then run the script.

## Streamed Data

Streamed data simulates an IoT device sending the following JSON data:

```json
{
    "eventId": "b81d241f-5187-40b0-ab2a-940faf9757c0",
    "complexData": {
        "moreData8": 51.3068118685458,
        "moreData9": 44.44672606436184,
        "moreData0": 57.739726013343247,
        "moreData1": 52.230732688620829,
        "moreData2": 57.497518587807189,
        "moreData3": 81.32211656749469,
        "moreData4": 54.412361539409427,
        "moreData5": 75.36416309399911,
        "moreData6": 71.53407865773488,
        "moreData7": 45.34076957651598
    },
    "value": 49.02278128887753,
    "deviceId": "contoso://device-id-1554",
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```

## Monitor performances

Please use Metrics pane in Stream Analytics for "Input/Output Events", "Watermark Delay" metrics. This last is especially important to understand if the processing engine is keeping up with the incoming data or is falling behind:

[New metric in Azure Stream Analytics tracks latency of your streaming pipeline](https://azure.microsoft.com/en-us/blog/new-metric-in-azure-stream-analytics-tracks-latency-of-your-streaming-pipeline/)

You can also use Event Hub "Metrics" pane:

[Understand Stream Analytics job monitoring and how to monitor queries](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-monitoring)

## Stream Analytics

At present time Azure Stream Analytics cannot send `record` data types to Azure SQL, as documented here: [Type mapping when writing to structured data stores](https://docs.microsoft.com/en-us/stream-analytics-query/data-types-azure-stream-analytics?toc=https%3A%2F%2Fdocs.microsoft.com%2Fen-us%2Fazure%2Fstream-analytics%2FTOC.json&bc=https%3A%2F%2Fdocs.microsoft.com%2Fen-us%2Fazure%2Fbread%2Ftoc.json#type-mapping-when-writing-to-structured-data-stores)

## Azure SQL

The solution allows you to test both row-store and column-store options. The deployed database has two tables

- `rawdata`
- `rawdata_cs`

The `rawdata_cs` table is then one using a clustered column-store index. Both tables also have a non-clustered primary key on the eventId column. Set the `SQL_TABLE_KIND` variable to `rowstore` or `columnstore` to run the solution against the table you are interested in testing.

Be aware that database log backup happens every 10 minutes circa, as described here: [Automated backups](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-automated-backups#how-often-do-backups-happen). This means that additional IO overhead needs to be taken into account, which is proportional to the amount of ingested rows. That's why to move from 5000 msgs/sec to 10000 msgs/sec a bump from S7 to P6 is needed. The Premium level provides much more IOs which is needed to allow backup to happen without impacting performances.

## Additional References

- [Column-oriented DBMS](https://en.wikipedia.org/wiki/Column-oriented_DBMS)
- [Columnstore indexes - Design guidance](https://docs.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance?view=sql-server-2017)
- [Azure Stream Analytics output to Azure SQL Database](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-sql-output-perf)

## Clean up

To remove all the created resource, you can just delete the related resource group

```bash
az group delete -n <resource-group-name>
```
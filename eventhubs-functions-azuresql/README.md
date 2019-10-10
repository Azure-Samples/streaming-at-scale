---
topic: sample
languages:
  - azurecli
  - csharp
  - json
  - sql
products:
  - azure
  - azure-container-instances
  - azure-event-hubs
  - azure-functions  
  - azure-sql-database
  - azure-storage
statusNotificationTargets:
  - algattik@microsoft.com
---

# Streaming at Scale with Azure Event Hubs, Functions and Azure SQL

This sample uses Azure SQL as database to store processed data. This is especially useful when you need to create a *Near-Real Time Operational Analytics*, where streaming data has to be ingested at scale and, at the same time, also queried to execute analytical queries. The ability to ingest data into a columnstore is vital to have expected query performances:

[Get started with Columnstore for real time operational analytics](https://docs.microsoft.com/en-us/sql/relational-databases/indexes/get-started-with-columnstore-for-real-time-operational-analytics?view=sql-server-2017)

The provided scripts will create an end-to-end solution complete with load test client.  

## Running the Scripts

Please note that the scripts have been tested on [Ubuntu 18 LTS](http://releases.ubuntu.com/18.04/), so make sure to use that environment to run the scripts. You can run it using Docker, WSL or a VM:

- [Ubuntu Docker Image](https://hub.docker.com/_/ubuntu/)
- [WSL Ubuntu 18.04 LTS](https://www.microsoft.com/en-us/p/ubuntu-1804-lts/9n9tngvndl3q?activetab=pivot:overviewtab)
- [Ubuntu 18.04 LTS Azure VM](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/Canonical.UbuntuServer1804LTS)

The following tools/languages are also needed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)
  - Install: `sudo apt install azure-cli`
- [jq](https://stedolan.github.io/jq/download/)
  - Install: `sudo apt install jq`
- [Zip](https://askubuntu.com/questions/660846/how-to-zip-and-unzip-a-directory-and-its-files-in-linux)
  - Install : `sudo apt install zip`
- [Dotnet Core](https://dotnet.microsoft.com/download/linux-package-manager/ubuntu18-04/sdk-current)

## Setup Solution

Make sure you are logged into your Azure account:

    az login

and also make sure you have the subscription you want to use selected

    az account list

if you want to select a specific subscription use the following command

    az account set --subscription <subscription_name>

once you have selected the subscription you want to use just execute the following command

    ./create-solution.sh -d <solution_name>

then `solution_name` value will be used to create a resource group that will contain all resources created by the script. It will also be used as a prefix for all resource create so, in order to help to avoid name duplicates that will break the script, you may want to generate a name using a unique prefix. **Please also use only lowercase letters and numbers only**, since the `solution_name` is also used to create a storage account, which has several constraints on characters usage:

[Storage Naming Conventions and Limits](https://docs.microsoft.com/en-us/azure/architecture/best-practices/naming-conventions#storage)

to have an overview of all the supported arguments just run

    ./create-solution.sh

**Note**
To make sure that name collisions will be unlikely, you should use a random string to give name to your solution. The following script will generated a 7 random lowercase letter name for you:

    ./_common/generate-solution-name.sh

## Created resources

The script will create the following resources:

- **Azure Container Instances** to host Spark Load Test Clients: by default one client will be created, generating a load of 1000 events/second
- **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clients
- **Azure Function**: to process data incoming from Event Hubs as a stream
- **Application Insight**: to monitor Azure Function performances
- **Azure SQL** Server and Database: to store and serve processed data

The Azure Function is created using .Net Core 2.1, so it can be compiled on any supported platform. I only tested compilation on Windows 10, though.

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

## Duplicate event handling

The solution currently does not perform event deduplication.  As there is a unique ID on the eventId field in Azure SQL Database, function invocations will fail for those duplicates and entire event batches would be discarded. Therefore, the solution is only suitable when the upstream event generation pipeline up to Event Hubs has at-most once delivery guarantees (i.e. fire and forget message delivery, where messages are not redelivered even if the Event Hub does not acknowledge reception).


## Solution customization

If you want to change some setting of the solution, like number of load test clients, Azure SQL Databsae tier and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_FUNCTION=Test0
    export PROC_FUNCTION_SKU=P2v2
    export PROC_FUNCTION_WORKERS=2
    export SQL_SKU=P1
    export SIMULATOR_INSTANCES=1

The above settings have been chosen to sustain a 1,000 msg/s stream. The script also contains settings for 5,000 msg/s and 10,000 msg/s.

## Monitor performance

In order to monitor performance of created solution you just have to open the created Application Insight resource and then open the "Live Metric Streams" and you'll be able to see in the "incoming request" the number of processed request per second. The number you'll see here is very likely to be lower than the number of messages/second sent by test clients since the Azure Function is configured to use batching".

Performance will be monitored and displayed on the console for 30 minutes also. More specifically Inputs and Outputs performance of Event Hub will be monitored. If everything is working correctly, the number of reported `IncomingMessages` and `OutgoingMessages` should be roughly the same. (Give couple of minutes for ramp-up)

![Console Performance Report](../_doc/_images/console-performance-monitor.png)

## Azure Functions

The deployed Azure Function solution contains one function

- Test0

The function read the data incoming from Even Hub, augment the received JSON by injecting a few additional elements and then send it to Azure SQL using Dapper (https://github.com/StackExchange/Dapper). Dapper has been chooses as it provides the best performance and is widespreadly used.

## Azure SQL

The solution allows you to test both row-store and column-store options. The deployed database has four tables

- `rawdata`
- `rawdata_cs`
- `rawdata_cs_mo`
- `rawdata_mo`

The suffix indicates which kind of storage is used for the table:

- No suffix: classic row-store table
- `cs`: column-store via clustered columnstore index
- `mo`: memory-optimized table
- `cs_mo`: memory-optimized clustered columnstore

Use the `-k` option and set it to `rowstore`, `columnstore`, `rowstore-inmemory` or `columnstore-inmemory` to run the solution against the table you are interested in testing.

Table Value Parameters are used to make sure data is sent to Azure SQL in the most efficient way, while keeping the latency as low as possibile

Be aware that database log backup happens every 10 minutes circa, as described here: [Automated backups](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-automated-backups#how-often-do-backups-happen). This means that additional IO overhead needs to be taken into account, which is proportional to the amount of ingested rows. That's why to move from 5000 msgs/sec to 10000 msgs/sec a bump from P4 to P6 is needed. The Premium level provides much more I/Os which are needed to allow backup to happen without impacting performances.

If you want to connect to Azure SQL to query data and/or check resources usages, here's the login and passoword:

```
User ID = serveradmin
Password = Strong_Passw0rd!
```

A note on in-memory tables: as mentioned in the documentation:

[Data size and storage cap for In-Memory OLTP](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-in-memory#data-size-and-storage-cap-for-in-memory-oltp)

there is a quota on the in-memory table size. In order to keep the quota below the maximum, a script that moves data from the in-memory table to disk-table is needed. The sample doesn't provide any automation to move data between table, but it would be easily implemented using a Azure Function with a Timer Trigger and a T-SQL like the following:

```sql
with cte as (
    select top (10000) * from dbo.rawdata_mo with (snapshot) order by ProcessedAt desc
)
insert into 
    dbo.rawdata
select * from 
(
    delete c output deleted.* from cte c
) d
```

A more detailed discussion of this tecnique along with source code is available here:

[Azure SQL Database: Ingesting 1.4 million sustained rows per second with In-Memory OLTP & Columnstore Index](https://techcommunity.microsoft.com/t5/Azure-SQL-Database/Azure-SQL-Database-Ingesting-1-4-million-sustained-rows-per/ba-p/386162)

## Exceptions

Just after starting the Azure Function, if you immediately go to the Application Insight blade on the Azure Portal, you may see the following exception:

    New receiver with higher epoch of '3' is created hence current receiver with epoch '2' is getting disconnected. If you are recreating the receiver, make sure a higher epoch is used.

You can safely ignore it since it happens just during startup time when EventProcessors are created. After couple of seconds the no more exception like that one will be thrown. No messages will be lost while these exceptions are fired.

## Additional References

- [Column-oriented DBMS](https://en.wikipedia.org/wiki/Column-oriented_DBMS)
- [Columnstore indexes - Design guidance](https://docs.microsoft.com/en-us/sql/relational-databases/indexes/columnstore-indexes-design-guidance?view=sql-server-2017)
- [Azure Stream Analytics output to Azure SQL Database](https://docs.microsoft.com/en-us/azure/stream-analytics/stream-analytics-sql-output-perf)

## Clean up

To remove all the created resource, you can just delete the related resource group

```bash
az group delete -n <resource-group-name>
```

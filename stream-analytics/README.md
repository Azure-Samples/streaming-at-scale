# Streaming at Scale with Stream Analytics

This sample uses Stream Analytics to process streaming data from EventHub and uses Cosmos DB as a sink to store JSON data

The provided scripts will an end-to-end solution complete with load test client.  

## Running the Scripts

Please note that the scripts have been tested on Windows 10 WSL/Ubuntu and macOS X, so make sure to use one of these two environment to run the scripts.

The following tools/languages are also needed:

- [AZ CLI](https://dotnet.microsoft.com/download/linux-package-manager/ubuntu16-04/sdk-current)
- [Python 3](http://ubuntuhandbook.org/index.php/2017/07/install-python-3-6-1-in-ubuntu-16-04-lts/)
- [Dotnet Core](https://dotnet.microsoft.com/download/linux-package-manager/ubuntu16-04/sdk-current)
- [Zip](https://askubuntu.com/questions/660846/how-to-zip-and-unzip-a-directory-and-its-files-in-linux)


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

The Azure Function is created using .Net Core 2.1, so it can be compiled on any supported platform. I only tested compilation on Windows 10, though.

## Solution customization

If you want to change some setting of the solution, like number of load test clients, Cosmos DB RU and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export PROC_STREAMING_UNITS=6
    export COSMOSDB_RU=10000
    export TEST_CLIENTS=2

The above settings has been chosen to sustain a 1000 msg/sec stream.

## Monitor performances

Please use Metrics pane in Stream Analytics for "Input/Output Events", "Watermark Delay" metrics . 
You can also use Event Hub "Metrics" pane.

## Stream Analytics

TBD. The deployed Stream Analytics solution doesn't do any analytics or projection , these will be added soon.

## Exceptions

NA

## Query Data

Data is available in the created Cosmos DB database. You can query it from the portal, for example:

    SELECT * FROM c WHERE c.eventData.type = 'CO2'

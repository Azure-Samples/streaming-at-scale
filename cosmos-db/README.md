# Streaming at Scale with Cosmos DB

This sample uses Cosmos DB as database to store JSON data

The provided scripts will an end-to-end solution complete with load test client.

## Running the Scripts

Please note that the scripts have been tested on Windows 10 WSL/Ubuntu and macOS X, so make sure to use one of these two environment to run the scripts.
A PowerShell script is also in the works.

## Setup Solution

Make sure you are logged into your Azure account:

    az login

and also make sure you have the subscription you want to use selected

    az account list

if you want to select a specific subscription use the following command

    az account set --subscription <subscription_name>

once you have selected the subscription you want to use just execute the following command

    ./create-solution.sh <solution_name>

then `solution_name` value will be used to create a resource group that will contain all resources created by the script. It will also be used as a prefix for all resource create so, in order to help to avoid name duplicates that will break the script, you may want to generated a name using a unique prefix. **Please also use only lowercase letters and numbers only**, since the `solution_name` is also used to create a storage account, which has several constraints on charachters usage:

[Storage Naming Conventions and Limits](https://docs.microsoft.com/en-us/azure/architecture/best-practices/naming-conventions#storage)

**Note**
To make sure that name collisions will be unlikely use a random string:

    echo `openssl rand 5 -base64 | cut -c1-7 | tr '[:upper:]' '[:lower:]' | tr -cd '[[:alnum:]]._-'`

## Created resources

The script will create the followin resources:

* **Azure Container Instances** to host [Locust]() Load Test Clients: by default two Locust client will be created, generating a load of 1000 events/second
* **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clientss
* **Azure Function**: to process data incoming from Event Hubs as a stream
* **Application Insight**: to monitor Azure Function performances
* **Cosmos DB** Server, Database and Collection: to store and serve processed data

The Azure Function is created using .Net Framework 4.6.1, so at the moment it can be compiled only on a Window OS. 

## Monitor performances

In order to monitor performance of created solution you just have to open the created Application Insight resource and then open the "Live Metric Streams" and you'll be able to see in the "incoming request" the number of processed request per second. The number you'll see here is very likely to be lower than the number of messages/second sent by test clients since the Azure Function is configured to use batching"

### Azure Functions
The deployed Azure Function solution contains two functions

* Test0
* Test1

The first one uses Cosmos DB binding for Azure Function, while the second one uses the SDK. Only one solution will be activated during deployment. By default the activated one is "Test1"

### Exceptions

Just after starting the Azure Function, if you immediately go to the Application Insight blade on the Azure Portal, you may see the followin exception:

    New receiver with higher epoch of '3' is created hence current receiver with epoch '2' is getting disconnected. If you are recreating the receiver, make sure a higher epoch is used.

You can safely ignore it since it happens just during startup time when EventProcessor are created. After couple of seconds the no more exception like that one will be thrown. No messages will be lost while these exceptions are fired.

## Query Data

Data is available in the created Cosmos DB database. You can query it from the portal, for example:

    SELECT * FROM c WHERE c.eventData.type = 'CO2'
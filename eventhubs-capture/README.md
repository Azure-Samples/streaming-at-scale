# Streaming at Scale with Event Hubs Capture

This sample uses Event Hubs Capture and Apache Drill to ingest data and make it available to be queried.

The provided scripts will an end-to-end solution complete with load test client.

## Running the Scripts

Please note that the scripts have been tested on Windows 10 WSL/Ubuntu and macOS X, so make sure to use one of these two environment to run the scripts.

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
To make sure that name collisions will be unlikely, you should use a random string to give name to your solution. The following script will generated a 7 random lowercase letter name for you:

    ./generate-solution-name.sh

## Created resources

The script will create the followin resources on Azure:

* **Azure Container Instances** to host [Locust](https://locust.io/) Load Test Clients: by default two Locust client will be created, generating a load of 1000 events/second
* **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clients

the script also tried to run a Docker container. Docker is therefore needed.

https://www.docker.com/get-started

If you're on Windows 10 and using WSL to run shell script, remember to configure Docker in WSL so that it can talk with the Docker installed on the host:

https://davidburela.wordpress.com/2018/06/27/running-docker-on-wsl-windows-subsystem-for-linux/

## Solution customization

If you want to change some setting of the solution, like number of load test clients, Event Hubs capacity and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

    export EVENTHUB_PARTITIONS=2
    export EVENTHUB_CAPACITY=2
    export TEST_CLIENTS=2

The above settings has been choosen to sustain a 1000 msg/sec stream.

## Query Data

Data sent to the created Event Hub will be stored automatically in Azure Blob Storage. The script will also download and execute on the local machine the Apache Drill Docker image and it will automatically configure it to use the aformentioned Azure Blob Storage.

Once the container is ready you can connect to Apache Drill via local console on web portal and then execute a SQL query to extract data from created Avro files:

List what sources are available. The `azure` source is the one automatically configured by the executed script.

    show databases;

You can see a list of files and folders available in the `azure` source:

    show files from azure;

    show files from azure.`folder/subfolder/desired-avro-file.avro`;

You can then query Avro file contents:

    select 
        t.B.`deviceId`, 
        t.B.`type`, 
        t.B.`value` 
    from 
        (
            select convert_from(Body, 'JSON') as B from azure.`folder/subfolder/desired-avro-file.avro` limit 10
        ) as t;"

## Using Apache Drill on Azure

As you may notice querying Avro files from your local machine may take a while. This is due to the fact that Apache Drill needs to pull all the data from Azure Blob Storage and store it temporarly on your machine. A better option is to run Apache Drill on Azure so all data movement will happen in the cloud:

https://github.com/yorek/apache-drill-azure-blob 

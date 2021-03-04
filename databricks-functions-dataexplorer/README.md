---
topic: sample
languages:
  - azurecli
  - json
  - powershell
  - python
products:
  - azure
  - azure-data-lake-storage
  - azure-event-grid
  - azure-functions
  - azure-databricks
  - azure-data-explorer
---

# Data lake storage, Event Grid, Databricks, Functions, and Data Explorer Solution

This folder contains a end-to-end streaming solution sample from data landing into DataLake storage, Databricks autoloader to partition the content and then azure function to ingest data into data explorer. Following you can find the instruction to collaborate by creating this end-to-end samples.

![architecture](artifacts/databricks-functions-dataexplorer.png)

## Running the Scripts
Please note that the scripts have been tested on [Ubuntu 18 LTS](http://releases.ubuntu.com/18.04/), so make sure to use that environment to run the scripts. You can run it using Docker, WSL or a VM:

- [Ubuntu Docker Image](https://hub.docker.com/_/ubuntu/)
- [WSL Ubuntu 18.04 LTS](https://www.microsoft.com/en-us/p/ubuntu-1804-lts/9n9tngvndl3q?activetab=pivot:overviewtab)
- [Ubuntu 18.04 LTS Azure VM](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/Canonical.UbuntuServer1804LTS)

The following tools are also needed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)
  - Install: `sudo apt install azure-cli`
- [jq](https://stedolan.github.io/jq/download/)
  - Install: `sudo apt install jq`
- [python]
  - Install: `sudo apt install python python-pip`
- [databricks-cli](https://github.com/databricks/databricks-cli)
  - Install: `pip install --upgrade databricks-cli`

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
    ./create-solution.sh -f infra/script/config/provision-config.local.json
    ./create-solution.sh -f infra/script/config/provision-config.local.json -s C

## Script content

### create-solution.sh

`create-solution.sh` is the script that the end user will execute to deploy the end-to-end solution. Take a look at it and change it to make sure it references the correct file. Section that you're likely to change are delimited with `BEGIN` and `END` comments.

The file does the following things:

* gets and validates the argument
* make sure required software are available
* exports the variables used in called scripts
* set correct values for 1, 5 and 10 msgs/sec test
* execute the requested step by executing the related scripts 

Code should be self-explanatory; if not, just ask.

### source ../components/azure-eventgrid/create-eventgrid.sh(new)

`create-eventgrid.sh`: this script creates the Event grid used for ingestion.

### source ../components/azure-storagequeue/create-storagequeue.sh(new)

`create-storagequeue.sh`: this script creates the storage queue used for ingestion.

### source ../components/azure-storage/create-storage-hfs.sh

`create-storage-hfs.sh`: this script creates a Data lake storage

### source ../components/azure-databricks/create-databricks.sh
`create-databricks.sh`: this script creates a Databricks

### source ../streaming/Databricks/notebooks/datalake-to-datalake
`datalake-to-datalake.py`: notebook code for data partition

### source ../streaming/Databricks/runners/datalake-to-datalake.sh
`datalake-to-datalake.sh`: this script creates a Databricks job to run the notebook (new)
### source ../components/azure-functions/create-processing-function.sh

### source ../components/azure-functions/configure-processing-function-storagequeue.sh (new)

`create-processing-function.sh`: this script creates an Azure Function for stream processing, again you can use another component instead, such as Databricks, or provide your own script.

`configure-processing-function-storagequeue.sh`: this script configures the Azure Function for input from storage queue

### source ../components/azure-dataexplorer/create-dataexplorer.sh
`create-dataexplorer.sh`: this script create dataexplorer and create database for data explorer

### source ../components/azure-dataexplorer/configure-dataexplorer.sh(new)
`configure-dataexplorer.sh`: this script configures the Azure Data Explorer ingestion policy
### source ../simulator/run-generator-datalake.sh(new)

`run-generator-datalake.sh` contains the code need to setup Spark clients, using Azure Container Instances.

Each client generates up to 2000 msgs/sec. Each generated message is close to 1KB and look like this:

```json
{
    "eventId": "b81d241f-5187-40b0-ab2a-940faf9757c0",
    "complexData": {
        "moreData0": 12.12345678901234,
        "moreData1": 12.12345678901234,
        "moreData2": 12.12345678901234,
        "moreData3": 12.12345678901234,
        "moreData4": 12.12345678901234,
        "moreData5": 12.12345678901234,
        "moreData6": 12.12345678901234,
        "moreData7": 12.12345678901234,
        "moreData8": 12.12345678901234,
        "moreData9": 12.12345678901234,
        "moreData10": 12.12345678901234,
        "moreData11": 12.12345678901234,
        "moreData12": 12.12345678901234,
        "moreData13": 12.12345678901234,
        "moreData14": 12.12345678901234,
        "moreData15": 12.12345678901234,
        "moreData16": 12.12345678901234,
        "moreData17": 12.12345678901234,
        "moreData18": 12.12345678901234,
        "moreData19": 12.12345678901234,
        "moreData20": 12.12345678901234,
        "moreData21": 12.12345678901234,
        "moreData22": 12.12345678901234
    },
    "value": 49.02278128887753,
    "deviceId": "contoso://device-id-1554",
    "deviceSequenceNumber": 0,
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```

and it will send data to the specified data lake and trigger eventgrid.

### source ../evaluation/azure-databricks/report-throughput.sh (new)

<!-- `report-throughput.sh` queries Azure Monitor for Event Hub metrics and reports incoming and outgoing messages per minute. Ideally after a ramp-up phase those two metrics should be similar. -->

## Created resources
  - **azure-data-lake-storage** : One for data landing and one for data ingestion 
  - **azure-event-grid** : One for data land into storage, eventgrid will send the message to storage queue, One data land into storage, eventgrid will send the message to storage queue
  - **azure-storage-queue** : one for Databricks autoloader, one for Azure function input
  - **azure-functions** : parse metadata and ingestion data into dataexplorer queue
  - **azure-databricks** : partition data by deviceid and type
  - **azure-data-explorer** : store and serve processed data
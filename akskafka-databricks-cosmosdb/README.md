---
topic: sample
languages:
  - azurecli
  - json
  - sql
  - scala
products:
  - azure
  - azure-container-instances
  - azure-cosmos-db
  - azure-databricks
  - azure-kubernetes-service
statusNotificationTargets:
  - algattik@microsoft.com
---

# Streaming at Scale with Kafka on Azure Kubernetes Service (AKS), Databricks and Cosmos DB

This sample uses Cosmos DB as database to store JSON data.

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
- [python](https://www.python.org/)
  - Install: `sudo apt install python python-pip`
- [databricks-cli](https://github.com/databricks/databricks-cli)
  - Install: `pip install --upgrade databricks-cli`
- [helm](https://helm.sh/)
  - Install: `https://github.com/helm/helm`
- [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)
  - Install: `sudo apt-get install -y kubectl`

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
- **Azure Kubernetes Service (AKS)** Kafka Cluster and Consumer Group: to ingest data incoming from test clients
- **Azure Databricks**: to process data incoming from Kafka on Azure Kubernetes Service (AKS) as a stream. Workspace, Job and related cluster will be created
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
    "deviceSequenceNumber": 0,
    "type": "CO2",
    "createdAt": "2019-05-16T17:16:40.000003Z"
}
```

## Duplicate event handling

In case the infrastructure fails and recovers, it could process a second time an event from Kafka on Azure Kubernetes Service (AKS) that has already been stored in Cosmos DB. The solution uses Cosmos DB Upsert functionality to make this operation idempotent, so that events are not duplicated in Cosmos DB (based on the eventId attribute).

In order to illustrate the effect of this, the event simulator is configured to randomly duplicate a small fraction of the messages (0.1% on average). Those duplicate will not be present in Cosmos DB.

## Solution customization

If you want to change some setting of the solution, like the number of load test clients, Cosmos DB RU and so on, you can do it right in the `create-solution.sh` script, by changing any of these values:

    export NODE_COUNT=9
    export VM_SIZE=Standard_DS2_v2
    export COSMOSDB_RU=20000
    export SIMULATOR_INSTANCES=1
    export DATABRICKS_NODETYPE=Standard_DS3_v2
    export DATABRICKS_WORKERS=2
    export DATABRICKS_MAXEVENTSPERTRIGGER=10000

The above settings have been chosen to sustain a 1,000 msg/s stream. The script also contains settings for 5,000 msg/s and 10,000 msg/s.

## Azure Databricks

At present time the Cosmos DB Spark Connector *does not* suport `timestamp` data type. If you try to send to Cosmos DB a dataframe containing a timestamp, in fact, you'll get the followin error:

```
java.lang.ClassCastException: java.lang.Long cannot be cast to java.sql.Timestamp
```

As a workaround the `timestamp` columns are sent to Cosmos DB as Strings.

## Cosmos DB

When scaling up you may have noticed that you need more RU that would you could expect. Assuming that Cosmos DB consume 7 RU per write, to stream 5000 msgs/sec you can expect to use up to 35000 RU. Instead the sample is using 50000. There are three main reasons that explain what that is happening:

1. indexing
2. document size
3. physical data distribution

Look at the details of the [Azure Functions sample](../eventhubs-functions-cosmosdb#cosmos-db) to see a detailed description of mentioned concepts.

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
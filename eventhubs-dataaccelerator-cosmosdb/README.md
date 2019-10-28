---
topic: sample
languages:
  - azurecli
  - json
  - sql
  - scala
products:
  - azure
  - azure-cosmos-db
  - azure-iot-hubs
  - azure-event-hubs
  - azure-hdinsights
  - data-accelerator
statusNotificationTargets:
  - cbrochu@microsoft.com
---

# Streaming at Scale with Azure Event Hubs (or IoT Hub or Kafka), Data Accelerator and Cosmos DB or (Blobs/Hubs/AzureSQL)

The provided scripts will enable a data pipeline solution using Data Accelerator for Apache Spark (on Azure HDInsight) complete with a load test service.  The code is provided as-is and resources are to be managed by the owner of the subscription.

This sample enables various inputs, including Event Hub, Iot Hub and Kafka, as well as various outputs, including a built-in dashboard, CosmosDB, Event Hub or Azure Blob. It uses Cosmos DB as a database to store JSON configuration data

## Running the Scripts

Please note that the scripts have been tested on Windows 10.  The following tools are also needed:

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt?view=azure-cli-latest)
  - Install: `sudo apt install azure-cli`
- [Data Accelerator](https://github.com/Microsoft/data-accelerator)
  - Clone the repo or download the DeploymentCloud folder

## Setup Solution

After downloading Data Accelerator Deployments scripts, per https://github.com/Microsoft/data-accelerator/wiki/Cloud-deployment, edit the 
common.parameters.txt under DeploymentCloud/Deployment.DataX, and provide TenantId and SubscriptionId. 

open a command prompt as an admin under the downloaded folder DeploymentCloud/Deployment.DataX and run :

    deploy.bat

## Created resources

The script will create the following resources in your subscriptions

- **Azure HDInsight**: to process data incoming from Event Hubs as a stream. Workspace, Job and related cluster will be created
- **Service Fabric cluster** Hosts the services that configures Flows, handle permissions and manages the metrics
- **Cosmos DB** Server, Database and Collection: to store configurations
- **App Service** Web site to host the Data Accelerator Portal where users create, configure and manage Flows
- **Cache for Redis** Stores metrics to display on the Data Accelerator Portal
- **Storage account** Store runtime configurations, sample data and user content
- **Vnet** Hdinsight and Service Fabric clusters will be hosted inside a vnet
- **Keyvault** Stores secrets for the system as well as any input from the user 
- **Application Insights Collects telemetry from the system to help diagnose issues
- **Event Hubs** Namespace, Hub and Consumer Group: to ingest data incoming from test clients as well as an instance to process metrics
- **IoT Hub** Namespace, Hub and Consumer Group: to ingest data incoming from test clients 
 

## Streamed Data

Streamed data simulates several IoT device sending the following JSON data:

```json
  {
    "eventTimeStamp": "2019-07-22T15:24:38.000Z",
    "deviceDetails": {
      "deviceId": 8,
      "deviceType": "GarageDoorLock",
      "eventTime": "07/22/2019 15:24:38",
      "homeId": 84,
      "status": 0
    }
    [...]
  }
```

## Solution customization

If you want to change settings of the solution, please see the ARM customization file (common.parameters.txt under DeploymentCloud\Deployment.DataX) and the matching documentation here: https://github.com/Microsoft/data-accelerator/wiki/Arm-Parameters

## Monitoring

After starting the sample Flow, you can view metrics on the Metrics page of the web portal of the instantiated solution.  This will give you metrics on the number of events going through the system as well as visualization of the data.

In order to monitor the system health, you can view the App Insight data of the created solution by opening the created Application Insight resource and then open the "Live Metric Streams".  You'll be able to see in the "incoming request" as well as any errors in requests.  You can read more on this here: https://github.com/Microsoft/data-accelerator/wiki/Diagnose-issues-using-Telemetry

## Clean up

To remove all the created resource, you can delete the related resource group (DataX)

```bash
az group delete -n DataX
```

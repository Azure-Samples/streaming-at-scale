---
page_type: sample
languages:
- csharp
products:
- azure
- azure eventhubs 
extensions:
- platforms: dotnet
---

# Getting started on processing received message from eventhub #

Azure eventhubs-streamanalytics-eventhubs sample for processing received message from eventhub -
 - Create an EventHubConsumerClient based on connection string for the `Listen` or `Manage` Shared Access Policy for the eventhub.
 - Read events from EventHubConsumerClient.
 - Processing received message and write to a .csv file.

# Running this Sample #
To run this sample:

If you don't have an Azure subscription, create a [free account] before you begin.
	
Go to [Azure portal], sign in with your account. You can find how to [create event hub service] from here. 

Get the EventHubConnectionString for the `Listen` or `Manage` Shared Access Policy for the eventhub.
	
Run git clone https://github.com/Azure-Samples/streaming-at-scale.git

From within the `eh-asa-perform` folder run:

```bash
dotnet run -- -c "<EventHubConnectionString>"
```
The application will read from the eventhub and will measure latency (difference from Enqueued and Processed time) for each batch of recevied messages.

<!-- LINKS -->
[free account]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[Azure portal]: https://ms.portal.azure.com/#home
[create event hub service]: https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-create
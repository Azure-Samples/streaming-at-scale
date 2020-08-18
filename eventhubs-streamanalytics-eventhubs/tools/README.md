---
page_type: sample
languages:
- csharp
products:
- azure
- azure-event-hubs 
extensions:
- platforms: dotnet
---

# Getting started on processing received message from Event Hubs #

The `eventhubs-streamanalytics-eventhubs` sample demonstrates processing messages from Event Hubs. The `EventReceiver` will:

 - Connect to an existing event hub.
 - Read events from all partitions using the `EventHubConsumerClient`.
 - Process each received message and output to a `.csv` file.

# Running this Sample #
To run this sample:

If you don't have an Azure subscription, create a [free account] before you begin.
	
Go to [Azure portal], sign in with your account. You can find how to [create event hub] from here. 

After creating an event hub within the Event Hubs namespace, you can get the Event Hub-level EventHubConnectionString with following steps.
	1. In the list of event hubs, select your event hub.
	2. On the Event Hubs Instance page, select Shared Access Policies on the left menu.
	3. Add a policy with appropriate permissions(Listen or Manage).
	4. Click on added policy.

Hints:While running this sample, You should have an existing Azure Stream Analytics configuration(a producer sends events)
that publishes events to this event hub.

Run the following command.
```bash	
git clone https://github.com/Azure-Samples/streaming-at-scale.git
```
From within the `eh-asa-perform` folder run:

```bash
dotnet run -- -c "<EventHubConnectionString>"
```
The application will read from the event hub and will measure latency (difference from Enqueued and Processed time) for each batch of recevied messages.

<!-- LINKS -->
[free account]: https://azure.microsoft.com/free/?WT.mc_id=A261C142F
[Azure portal]: https://portal.azure.com/
[create event hub]: https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-create
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.Documents;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.WebJobs.ServiceBus;
using System;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.ServiceBus.Messaging;
using System.Text;
using System.Collections.Generic;

namespace StreamingProcessor
{
    public static class Test0
    {
        /*
         * Cosmos DB output using Azure Function binding
         */
        [FunctionName("Test0")]
        public static async Task RunAsync(
            [EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup="%ConsumerGroup%")] EventData[] eventHubData,
            [DocumentDB(databaseName: "%CosmosDBDatabaseName%", collectionName: "%CosmosDBCollectionName%", ConnectionStringSetting = "CosmosDBConnectionString")] IAsyncCollector<string> cosmosMessage,
        TraceWriter log)
        {
            var tasks = new List<Task>();

            Stopwatch sw = new Stopwatch();
            sw.Start();

            foreach (var data in eventHubData)
            {
                try
                {
                    string message = Encoding.UTF8.GetString(data.GetBytes());

                    var document = new
                    {
                        eventData = JObject.Parse(message),
                        enqueuedAt = data.EnqueuedTimeUtc,
                        storedAt = DateTime.UtcNow
                    };

                    tasks.Add(cosmosMessage.AddAsync(JsonConvert.SerializeObject(document)));
                }
                catch (Exception ex)
                {
                    log.Error($"{ex} - {ex.Message}");
                }
            }

            await Task.WhenAll(tasks);

            sw.Stop();

            string logMessage = $"T: {eventHubData.Length} doc - E:{sw.ElapsedMilliseconds} msec";
            if (eventHubData.Length > 0)
            {
                logMessage += Environment.NewLine + $"AVG: {(sw.ElapsedMilliseconds / eventHubData.Length):N3} msec";
            }

            log.Info(logMessage);
        }
    }
}

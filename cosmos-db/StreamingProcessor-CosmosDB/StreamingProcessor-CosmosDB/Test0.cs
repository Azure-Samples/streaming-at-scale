using Microsoft.Azure.WebJobs;
using Microsoft.Azure.Documents;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.WebJobs.ServiceBus;
using System;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Diagnostics;
using System.Threading.Tasks;

namespace StreamingProcessor
{
    public static class Test0
    {
        /*
         * Cosmos DB output using Azure Function binding
         */
        [FunctionName("Test0")]
        public static async Task RunAsync([EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup="%ConsumerGroup%")]string[] eventHubMessages,
            [DocumentDB(databaseName: "%CosmosDBDatabaseName%",
            collectionName: "%CosmosDBCollectionName%",
            ConnectionStringSetting = "CosmosDBConnectionString")] IAsyncCollector<string> cosmosMessage,
        TraceWriter log)
        {
            DateTime startedAt = DateTime.UtcNow;
            Stopwatch sw = new Stopwatch();
            sw.Start();

            foreach (var message in eventHubMessages)
            {
                try
                {
                    var document = new
                    {
                        eventData = JObject.Parse(message),
                        storedAt = DateTime.UtcNow
                    };                    

                    
                    await cosmosMessage.AddAsync(JsonConvert.SerializeObject(document));
                }
                catch (Exception ex)
                {
                    log.Error($"{ex} - {ex.Message}");
                }
            }

            sw.Stop();

            log.Info($"{eventHubMessages.Length} messages were sent to db in {sw.ElapsedMilliseconds} msec");
        }
    }
}

using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.WebJobs.ServiceBus;
using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Client;
using Newtonsoft.Json.Linq;

namespace StreamingProcessor
{
    public static class Test1
    {
        /*
         * Cosmos DB output without using binding
         */
        [FunctionName("Test1")]
        public static async Task RunAsync([EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup="%ConsumerGroup%")]string[] eventHubMessages,
            TraceWriter log)
        {
            var client = await CosmosDBClient.GetClient();            

            DateTime startedAt = DateTime.UtcNow;
            Stopwatch sw = new Stopwatch();
            sw.Start();

            double totalRUbyBatch = 0;

            foreach (var message in eventHubMessages)
            {
                try
                {
                    var documentPayload = new
                    {
                        eventData = JObject.Parse(message),
                        storedAt = DateTime.UtcNow
                    };
                        
                    var document = await client.CreateDocumentAsync(documentPayload);
                    totalRUbyBatch += document.RequestCharge;
                }
                catch (Exception ex)
                {
                    log.Error($"{ex} - {ex.Message}");
                }                    
            }                    

            sw.Stop();

            string logMessage = $"{eventHubMessages.Length} messages were sent to db in {sw.ElapsedMilliseconds} msec";            
            if (eventHubMessages.Length > 0)
                logMessage += Environment.NewLine + $"Total RU Used: {totalRUbyBatch}. RU per document: {totalRUbyBatch/eventHubMessages.Length}";

            log.Info(logMessage);
        }
    }
}

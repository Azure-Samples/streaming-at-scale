using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.WebJobs.ServiceBus;
using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Client;
using Newtonsoft.Json.Linq;
using Microsoft.ServiceBus.Messaging;
using System.Text;

namespace StreamingProcessor
{
    public static class Test1
    {
        /*
         * Cosmos DB output without using binding
         */
        [FunctionName("Test1")]
        public static async Task RunAsync([EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup="%ConsumerGroup%")]EventData[] eventHubData, TraceWriter log)
        {
            var client = await CosmosDBClient.GetClient();            

            DateTime startedAt = DateTime.UtcNow;
            Stopwatch sw = new Stopwatch();
            sw.Start();

            double totalRUbyBatch = 0;

            foreach (var data in eventHubData)
            {
                try
                {
                    string message = Encoding.UTF8.GetString(data.GetBytes());

                    var documentPayload = new
                    {
                        eventData = JObject.Parse(message),
                        enqueuedAt = data.EnqueuedTimeUtc,
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

            string logMessage = $"T: {eventHubData.Length} doc - E:{sw.ElapsedMilliseconds} msec";
            if (eventHubData.Length > 0)
            {
                logMessage += Environment.NewLine + $"AVG: {sw.ElapsedMilliseconds / eventHubData.Length} msec";
                logMessage += Environment.NewLine + $"RU: {totalRUbyBatch}. AVG RU: {totalRUbyBatch / eventHubData.Length}";                
            }

            log.Info(logMessage);
        }
    }
}

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
using System.Collections.Generic;

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

            var tasks = new List<Task<ResourceResponse<Document>>>();

            Stopwatch sw = new Stopwatch();
            sw.Start();

            double totalRUbyBatch = 0;
            int positionInBatch = 1;
            foreach (var data in eventHubData)
            {
                try
                {
                    string message = Encoding.UTF8.GetString(data.GetBytes());

                    var documentPayload = new
                    {
                        eventData = JObject.Parse(message),
                        enqueuedAt = data.EnqueuedTimeUtc,
                        storedAt = DateTime.UtcNow,
                        positionInBatch
                    };

                    tasks.Add(client.CreateDocumentAsync(documentPayload));

                    positionInBatch += 1;
                }
                catch (Exception ex)
                {
                    log.Error($"{ex} - {ex.Message}");
                }
            }

            await Task.WhenAll(tasks);

            foreach (var t in tasks)
            {
                totalRUbyBatch += t.GetAwaiter().GetResult().RequestCharge;
            }

            sw.Stop();

<<<<<<< HEAD:cosmos-db/StreamingProcessor-CosmosDB/StreamingProcessor-CosmosDB/Test1.cs
            string logMessage = $"T:{eventHubData.Length} doc - E:{sw.ElapsedMilliseconds} msec";
=======
            string logMessage = $"[Test1] T:{eventHubData.Length} doc - E:{sw.ElapsedMilliseconds} msec";
>>>>>>> 313fd50960d7597ab2410d0835baf5091af3a26e:cosmos-db/StreamingProcessor-CosmosDB-Test1/StreamingProcessor-CosmosDB/Test1.cs
            if (eventHubData.Length > 0)
            {
                logMessage += Environment.NewLine + $"AVG:{(sw.ElapsedMilliseconds / eventHubData.Length):N3} msec";
                logMessage += Environment.NewLine + $"RU:{totalRUbyBatch}. AVG RU:{(totalRUbyBatch / eventHubData.Length):N3}";                
            }

            log.Info(logMessage);
        }
    }
}

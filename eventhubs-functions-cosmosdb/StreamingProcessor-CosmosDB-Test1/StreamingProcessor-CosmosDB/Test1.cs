using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using System;
using System.Diagnostics;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;
using System.Text;
using System.Collections.Generic;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.Documents.Client;
using Microsoft.Azure.Documents;

namespace StreamingProcessor
{
    public static class Test1
    {
        /*
         * Cosmos DB output without using binding
         */
        [FunctionName("Test1")]
        public static async Task RunAsync([EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup="%ConsumerGroup%")]EventData[] eventHubData, ILogger log)
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
                    string message = Encoding.UTF8.GetString(data.Body.Array);

                    var document = JObject.Parse(message);
                    document["enqueuedAt"] = data.SystemProperties.EnqueuedTimeUtc;
                    document["processedAt"] = DateTime.UtcNow;
                    document["positionInBatch"] = positionInBatch;

                    tasks.Add(client.CreateDocumentAsync(document));

                    positionInBatch += 1;
                }
                catch (Exception ex)
                {
                    log.LogError($"{ex} - {ex.Message}");
                }
            }

            await Task.WhenAll(tasks);

            foreach (var t in tasks)
            {
                totalRUbyBatch += t.GetAwaiter().GetResult().RequestCharge;
            }

            sw.Stop();

            string logMessage = $"[Test1] T:{eventHubData.Length} doc - E:{sw.ElapsedMilliseconds} msec";
            if (eventHubData.Length > 0)
            {
                logMessage += Environment.NewLine + $"AVG:{(sw.ElapsedMilliseconds / eventHubData.Length):N3} msec";
                logMessage += Environment.NewLine + $"RU:{totalRUbyBatch}. AVG RU:{(totalRUbyBatch / eventHubData.Length):N3}";                
            }

            log.LogInformation(logMessage);
        }
    }
}

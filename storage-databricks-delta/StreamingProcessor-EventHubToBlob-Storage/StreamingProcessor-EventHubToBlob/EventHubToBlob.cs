namespace StreamingProcessor
{
    using System;
    using System.IO;
    using System.Text;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;

    public static class EventHubToBlob
    {
        [FunctionName("EventHubToBlob")]
        public static void Run(
            [EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString",
                ConsumerGroup = "%ConsumerGroup%")]
            EventData[] eventHubData,
            [Blob("streamingatscale/ingestion/{sys.randguid}.json", FileAccess.Write, Connection = "StorageConnectionString")]
            Stream output,
            ILogger log)
        {
            foreach (var message in eventHubData)
            {
                output.Write(message.Body);
                output.WriteByte(0x0a);
            }
        }
    }
}
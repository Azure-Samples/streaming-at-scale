namespace EventHubToDigitalTwins
{
    using System;
    using System.Net.Http;
    using System.Text.Json;
    using System.Threading.Tasks;
    using Azure;
    using Azure.Core.Pipeline;
    using Azure.DigitalTwins.Core;
    using Azure.Identity;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;

    public class EventHubToDigitalTwins
    {
        //Your Digital Twin URL is stored in an application setting in Azure Functions
        private static readonly string AdtInstanceUrl = Environment.GetEnvironmentVariable("ADT_SERVICE_URL") ??
                                                        throw new InvalidOperationException(
                                                            "Application setting \"ADT_SERVICE_URL\" not set");

        private static readonly HttpClient HttpClient = new HttpClient();
        private static readonly DigitalTwinsClient Client;

        static EventHubToDigitalTwins()
        {
            //Authenticate with Digital Twins
            var cred = new DefaultAzureCredential();
            Client = new DigitalTwinsClient(new Uri(AdtInstanceUrl), cred,
                new DigitalTwinsClientOptions {Transport = new HttpClientTransport(HttpClient)});
        }

        [FunctionName("EventHubToDigitalTwins")]
        public async Task Run([EventHubTrigger("", Connection = "EVENT_HUB")]
            EventData[] events, ILogger log)
        {
            try
            {
                foreach (var eventData in events)
                {
                    await ProcessEvent(eventData, log);
                }
            }
            catch (Exception e)
            {
                log.LogError(e, e.Message);
            }
        }

        private static async Task ProcessEvent(EventData eventData, ILogger log)
        {
            try
            {
                var body = JsonDocument.Parse(eventData.Body).RootElement;
                var deviceId = body.GetProperty("deviceId").GetString();
                var deviceType = body.GetProperty("type").GetString();
                log.LogInformation($"DeviceId:{deviceId}. TwinId:{deviceId}. DeviceType:{deviceType}");
                var updateTwinData = new JsonPatchDocument();
                updateTwinData.AppendAdd("/LastUpdate", body.GetProperty("createdAt").GetDateTimeOffset());
                switch (deviceType)
                {
                    case "TEMP":
                        updateTwinData.AppendAdd("/Temperature", body.GetProperty("value").GetDouble());
                        updateTwinData.AppendAdd("/TemperatureData", body.GetProperty("complexData"));
                        break;
                    case "CO2":
                        updateTwinData.AppendAdd("/CO2", body.GetProperty("value").GetDouble());
                        updateTwinData.AppendAdd("/CO2Data", body.GetProperty("complexData"));
                        break;
                }

                await Client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
            }
            catch (Exception e)
            {
                log.LogError(e, e.Message);
            }
        }
    }
}
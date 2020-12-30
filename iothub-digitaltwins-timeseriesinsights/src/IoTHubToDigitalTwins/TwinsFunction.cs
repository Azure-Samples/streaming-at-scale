namespace IoTHubToDigitalTwins
{
    using System;
    using System.Net.Http;
    using System.Text.Json;
    using System.Threading.Tasks;
    using Azure;
    using Azure.Core.Pipeline;
    using Azure.DigitalTwins.Core;
    using Azure.Identity;
    using Microsoft.Azure.EventGrid.Models;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Azure.WebJobs.Extensions.EventGrid;
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

        [FunctionName("IoTHubToDigitalTwins")]
        public async Task Run([EventGridTrigger] EventGridEvent[] events, ILogger log)
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

        private static async Task ProcessEvent(EventGridEvent eventData, ILogger log)
        {
            try
            {
                log.LogInformation("Message: {data}", eventData.Data);
                var data = JsonDocument.Parse(eventData.Data.ToString()).RootElement;
                var body = data.GetProperty("body");
                var systemProperties = data.GetProperty("systemProperties");
                var deviceId = systemProperties.GetProperty("iothub-connection-device-id").GetString();
                if (systemProperties.GetProperty("iothub-message-source").GetString() != "Telemetry")
                {
                    return;
                }

                if (systemProperties.GetProperty("iothub-content-type").GetString() != "application/json")
                {
                    return;
                }

                var updateType = body.GetProperty("type").GetString();
                log.LogInformation("DeviceId:{deviceId}. UpdateType:{updateType}", deviceId, updateType);
                var updateTwinData = new JsonPatchDocument();
                updateTwinData.AppendAdd("/LastUpdate", body.GetProperty("createdAt").GetDateTimeOffset());
                switch (updateType)
                {
                    case "TEMP":
                        updateTwinData.AppendAdd("/Temperature", body.GetProperty("value").GetDouble());
                        updateTwinData.AppendAdd("/TemperatureData", body.GetProperty("complexData"));
                        break;
                    case "CO2":
                        updateTwinData.AppendAdd("/CO2", body.GetProperty("value").GetDouble());
                        updateTwinData.AppendAdd("/CO2Data", body.GetProperty("complexData"));
                        break;
                    default:
                        log.LogWarning("Unknown update type {updateType}", updateType);
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
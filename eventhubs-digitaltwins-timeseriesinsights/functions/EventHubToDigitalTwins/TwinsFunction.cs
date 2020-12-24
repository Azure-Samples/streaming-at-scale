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

    public class TwinsFunction
    {
        //Your Digital Twin URL is stored in an application setting in Azure Functions
        private static readonly string AdtInstanceUrl = Environment.GetEnvironmentVariable("ADT_SERVICE_URL") ??
                                                        throw new InvalidOperationException(
                                                            "Application setting \"ADT_SERVICE_URL\" not set");

        private static readonly HttpClient HttpClient = new HttpClient();

        [FunctionName("TwinsFunction")]
        public async Task Run([EventHubTrigger("", Connection = "EVENT_HUB")]
            EventData eventData, ILogger log)
        {
            try
            {
                //Authenticate with Digital Twins
                ManagedIdentityCredential cred = new ManagedIdentityCredential("https://digitaltwins.azure.net");
                DigitalTwinsClient client = new DigitalTwinsClient(new Uri(AdtInstanceUrl), cred,
                    new DigitalTwinsClientOptions {Transport = new HttpClientTransport(HttpClient)});
                log.LogInformation($"ADT service client connection created.");
                if (eventData != null && eventData.Body != null)
                {
                    log.LogInformation(eventData.ToString());

                    // Reading deviceId and temperature for IoT Hub JSON
                    var body = JsonDocument.Parse(eventData.Body).RootElement;
                    var deviceId = body.GetProperty("deviceId").GetString();
                    var deviceType = body.GetProperty("type").GetString();
                    log.LogInformation($"Device:{deviceId} DeviceType is:{deviceType}");
                    var updateTwinData = new JsonPatchDocument();
                    switch (deviceType)
                    {
                        case "TEMP":
                            updateTwinData.AppendAdd("/Temperature", body.GetProperty("value").GetDouble());
                            updateTwinData.AppendAdd("/TemperatureData", body.GetProperty("complexData"));
                            await client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
                            break;
                        case "CO2":
                            updateTwinData.AppendAdd("/CO2", body.GetProperty("value").GetDouble());
                            updateTwinData.AppendAdd("/CO2Data", body.GetProperty("complexData"));
                            await client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
                            break;
                    }
                }
            }
            catch (Exception e)
            {
                log.LogError(e, e.Message);
            }
        }
    }
}
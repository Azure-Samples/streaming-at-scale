namespace EventHubToDigitalTwins
{
    using System;
    using System.Net.Http;
    using System.Text;
    using Azure;
    using Azure.Core.Pipeline;
    using Azure.DigitalTwins.Core;
    using Azure.Identity;
    using Microsoft.Azure.EventHubs;
    using Microsoft.Azure.WebJobs;
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Linq;

    public class TwinsFunction
    {
        //Your Digital Twin URL is stored in an application setting in Azure Functions
        private static readonly string AdtInstanceUrl = Environment.GetEnvironmentVariable("ADT_SERVICE_URL");
        private static readonly HttpClient HttpClient = new HttpClient();

        [FunctionName("TwinsFunction")]
        public async void Run([EventHubTrigger("", Connection = "EVENT_HUB")]
            EventData eventData, ILogger log)
        {
            if (AdtInstanceUrl == null) log.LogError("Application setting \"ADT_SERVICE_URL\" not set");
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
                    JObject body =
                        (JObject) JsonConvert.DeserializeObject(Encoding.UTF8.GetString(eventData.Body));
                    var deviceId = (string) eventData.SystemProperties["iothub-connection-device-id"];
                    var deviceType = (string) body["DeviceType"];
                    log.LogInformation($"Device:{deviceId} DeviceType is:{deviceType}");
                    var updateTwinData = new JsonPatchDocument();
                    switch (deviceType)
                    {
                        case "FanningSensor":
                            updateTwinData.AppendAdd("/ChasisTemperature",
                                body["ChasisTemperature"].Value<double>());
                            updateTwinData.AppendAdd("/FanSpeed", body["Force"].Value<double>());
                            updateTwinData.AppendAdd("/RoastingTime",
                                body["RoastingTime"].Value<int>());
                            updateTwinData.AppendAdd("/PowerUsage",
                                body["PowerUsage"].Value<double>());
                            await client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
                            break;
                        case "GrindingSensor":
                            updateTwinData.AppendAdd("/ChasisTemperature",
                                body["ChasisTemperature"].Value<double>());
                            updateTwinData.AppendAdd("/Force", body["Force"].Value<double>());
                            updateTwinData.AppendAdd("/PowerUsage",
                                body["PowerUsage"].Value<double>());
                            updateTwinData.AppendAdd("/Vibration", body["Vibration"].Value<double>());
                            await client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
                            break;
                        case "MouldingSensor":
                            updateTwinData.AppendAdd("/ChasisTemperature",
                                body["ChasisTemperature"].Value<double>());
                            updateTwinData.AppendAdd("/PowerUsage",
                                body["PowerUsage"].Value<double>());
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
namespace EventHubToDigitalTwins
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Net.Http;
    using System.Text.Json;
    using System.Threading.Tasks;
    using System.Threading.Tasks.Dataflow;
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

        private static readonly bool SendTelemetry =
            Boolean.Parse(Environment.GetEnvironmentVariable("SEND_ADT_TELEMETRY_EVENTS") ?? "false");

        private static readonly bool SendUpdate =
            Boolean.Parse(Environment.GetEnvironmentVariable("SEND_ADT_PROPERTY_UPDATES") ?? "true");

        private static readonly HttpClient HttpClient = new HttpClient();
        private static readonly DigitalTwinsClient Client;
        private const int MaxConcurrentCalls = 128;

        static EventHubToDigitalTwins()
        {
            //Authenticate with Digital Twins
            var cred = new DefaultAzureCredential();
            Client = new DigitalTwinsClient(new Uri(AdtInstanceUrl), cred,
                new DigitalTwinsClientOptions {Transport = new HttpClientTransport(HttpClient)});
        }

        private readonly ILogger _log;

        public EventHubToDigitalTwins(ILogger<EventHubToDigitalTwins> log)
        {
            this._log = log;
        }

        [FunctionName("EventHubToDigitalTwins")]
        public async Task Run([EventHubTrigger("", Connection = "EVENT_HUB")]
            EventData[] events)
        {
            _log.LogInformation("Received {numEvents} events", events.Length);
            try
            {
                var output = await events.ToAsyncEnumerable().AsyncParallelForEach(ProcessEvent, MaxConcurrentCalls)
                    .ToListAsync();
                var numErrors = output.Count(_ => _.Exception is { });
                var durations = output.Select(_ => _.Duration).ToList();
                _log.LogInformation(
                    "Processed {numEvents} events with {numErrors} errors, duration {min}-{max} avg {avg} ms",
                    output.Count,
                    numErrors,
                    durations.Min(),
                    durations.Max(),
                    Convert.ToInt64(durations.Average())
                );
            }
            catch (Exception e)
            {
                _log.LogError(e, e.Message);
            }
        }

        private async Task<Result> ProcessEvent(EventData eventData)
        {
            Stopwatch stopwatch = new Stopwatch();
            stopwatch.Start();
            try
            {
                var body = JsonDocument.Parse(eventData.Body).RootElement;
                var eventId = body.GetProperty("eventId").GetString();
                var deviceId = body.GetProperty("deviceId").GetString();
                var updateType = body.GetProperty("type").GetString();
                var createdAt = body.GetProperty("createdAt").GetDateTimeOffset();
                var deviceSequenceNumber = body.GetProperty("deviceSequenceNumber").GetInt64();
                var value = body.GetProperty("value").GetDouble();
                var complexData = body.GetProperty("complexData");

                if (SendUpdate)
                {
                    _log.LogDebug("DeviceId:{deviceId}. UpdateType:{updateType}", deviceId, updateType);

                    await SendUpdateAsync(deviceId, updateType, value, complexData, deviceSequenceNumber, createdAt);
                }

                if (SendTelemetry)
                {
                    await SendTelemetryAsync(eventId, deviceId, updateType, value, complexData, deviceSequenceNumber,
                        createdAt);
                }

                return new Result {Duration = stopwatch.ElapsedMilliseconds};
            }
            catch (Exception e)
            {
                _log.LogError(e, e.Message);
                return new Result {Exception = e, Duration = stopwatch.ElapsedMilliseconds};
            }
        }

        private async Task SendTelemetryAsync(string eventId, string deviceId, string updateType, double value,
            JsonElement complexData, long deviceSequenceNumber, DateTimeOffset createdAt)
        {
            var telemetryEvent = new Dictionary<string, object>
            {
                {"eventId", eventId},
                {"deviceId", deviceId},
                {"LastUpdate", createdAt},
                {"deviceSequenceNumber", deviceSequenceNumber}
            };
            switch (updateType)
            {
                case "TEMP":
                    telemetryEvent.Add("Temperature", value);
                    telemetryEvent.Add("TemperatureData", complexData);
                    break;
                case "CO2":
                    telemetryEvent.Add("CO2", value);
                    telemetryEvent.Add("CO2Data", complexData);
                    break;
                default:
                    _log.LogWarning("Unknown update type {updateType}", updateType);
                    break;
            }

            var payload = JsonSerializer.Serialize(telemetryEvent);
            await Client.PublishTelemetryAsync(deviceId, eventId, payload, createdAt);
        }

        private async Task SendUpdateAsync(string deviceId, string updateType, double value, JsonElement complexData,
            long deviceSequenceNumber, DateTimeOffset createdAt)
        {
            var updateTwinData = new JsonPatchDocument();
            updateTwinData.AppendAdd("/LastUpdate", createdAt);
            updateTwinData.AppendAdd("/deviceSequenceNumber", deviceSequenceNumber);
            switch (updateType)
            {
                case "TEMP":
                    updateTwinData.AppendAdd("/Temperature", value);
                    updateTwinData.AppendAdd("/TemperatureData", complexData);
                    break;
                case "CO2":
                    updateTwinData.AppendAdd("/CO2", value);
                    updateTwinData.AppendAdd("/CO2Data", complexData);
                    break;
                default:
                    _log.LogWarning("Unknown update type {updateType}", updateType);
                    break;
            }

            await Client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
        }
    }

    internal class Result
    {
        public Exception? Exception { get; set; }
        public long Duration { get; set; }
    }

    internal static class Extensions
    {
        public static async IAsyncEnumerable<TOutput> AsyncParallelForEach<TInput, TOutput>(
            this IAsyncEnumerable<TInput> source, Func<TInput, Task<TOutput>> body,
            int maxDegreeOfParallelism = DataflowBlockOptions.Unbounded, TaskScheduler? scheduler = null)
        {
            var options = new ExecutionDataflowBlockOptions
            {
                MaxDegreeOfParallelism = maxDegreeOfParallelism
            };
            if (scheduler != null)
                options.TaskScheduler = scheduler;
            var block = new TransformBlock<TInput, TOutput>(body, options);
            var nItems = 0;
            await foreach (var item in source)
            {
                block.Post(item);
                nItems++;
            }

            for (var i = 0; i < nItems; i++)
            {
                yield return await block.ReceiveAsync();
            }
        }
    }
}
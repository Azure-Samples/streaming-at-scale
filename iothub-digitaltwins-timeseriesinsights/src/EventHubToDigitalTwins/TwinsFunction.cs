namespace EventHubToDigitalTwins
{
    using System;
    using System.Collections.Generic;
    using System.Diagnostics;
    using System.Linq;
    using System.Net.Http;
    using System.Text;
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
                // await events.ToAsyncEnumerable().AsyncParallelForEach(ProcessEvent, MaxConcurrentCalls);
                var output = await events.ToAsyncEnumerable().AsyncParallelForEach(ProcessEvent, MaxConcurrentCalls).ToListAsync();
                var inp = output.Select(_ => Encoding.UTF8.GetString(_.In));
                var numErrors = output.Count(_ => _.Exception is { });
                var durations = output.Select(_ => _.Duration).ToList();
                _log.LogInformation("Processed {numEvents} events with {numErrors} errors, duration {min}-{max} avg {avg} ms",
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
            Stopwatch w = new Stopwatch();
            w.Start();
            try
            {
                var body = JsonDocument.Parse(eventData.Body).RootElement;
                var deviceId = body.GetProperty("deviceId").GetString();
                var updateType = body.GetProperty("type").GetString();
                _log.LogDebug("DeviceId:{deviceId}. UpdateType:{updateType}", deviceId, updateType);
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
                        _log.LogWarning("Unknown update type {updateType}", updateType);
                        break;
                }

                var output = await Client.UpdateDigitalTwinAsync(deviceId, updateTwinData);
                return new Result {Response = output, Duration = w.ElapsedMilliseconds, In = eventData.Body};
            }
            catch (Exception e)
            {
                _log.LogError(e, e.Message);
                return new Result {Exception = e, Duration = w.ElapsedMilliseconds, In = eventData.Body};
            }
        }
    }

    class Result
    {
        public Response? Response { get; set; }
        public Exception? Exception { get; set; }
        public long Duration { get; set; }
        public ArraySegment<byte> In { get; set; }
    }

    static class Extensions
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
            await foreach (var item in source)
            {
                block.Post(item);
                yield return block.Receive();
            }
        }
    }
}
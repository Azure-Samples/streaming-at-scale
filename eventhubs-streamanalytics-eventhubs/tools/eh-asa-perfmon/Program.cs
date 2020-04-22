using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Consumer;
using Azure.Messaging.EventHubs.Producer;
using CommandLine;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace StreamingAtScale
{
    public class Options
    {
        [Option('c', "connectionString", Required = true, HelpText = "Event Hub connection string. It must be a Event Hub (not Namespace!) connection string.")]
        public string EventHubConnectionString { get; set; }
    }

    class MyPartitionReceiver
    {
        private readonly object _lock = new object();
        private readonly string _partitionId = string.Empty;
        private readonly StreamWriter _csvOutput = null;

        private int _maxBatchSize = 3;

        public int MaxBatchSize { get => _maxBatchSize; set => _maxBatchSize = value; }

        public MyPartitionReceiver(string partitionId, StreamWriter csvOutput)
        {
            this._partitionId = partitionId;
            this._csvOutput = csvOutput;
        }

        public Task ProcessEventsAsync(IEnumerable<EventData> events)
        {
            int eventCount = 0;

            var listTS = new List<TimeSpan>();
            var listDT = new List<DateTimeOffset>();

            foreach (var e in events)
            {
                var eventBody = Encoding.UTF8.GetString(e.Body.ToArray()).Split('\n');

                foreach (var b in eventBody)
                {
                    try
                    {
                        var message = JsonConvert.DeserializeObject<JObject>(b, new JsonSerializerSettings() { DateParseHandling = DateParseHandling.None });
                        eventCount += 1;

                        var timeCreated = DateTime.Parse(message["createdAt"].ToString());
                        var timeIn = DateTime.Parse(message["EventEnqueuedUtcTime"].ToString());
                        var timeProcessed = DateTime.Parse(message["EventProcessedUtcTime"].ToString());
                        var timeASAProcessed = DateTime.Parse(message["ASAProcessedUtcTime"].ToString());
                        var timeOut = e.EnqueuedTime.UtcDateTime.ToLocalTime();

                        listDT.Add(timeIn);
                        var elapsed = timeOut - timeIn;
                        listTS.Add(elapsed);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine("Error while parsing event body.");
                        Console.WriteLine("Error:" + ex.Message);
                        Console.WriteLine("Message:" + b);
                    }
                }
            }

            var batchFrom = listDT.Min();
            var batchTo = listDT.Min();
            var minLatency = listTS.Min().TotalMilliseconds;
            var maxLatency = listTS.Max().TotalMilliseconds;
            var avgLatency = Math.Round(listTS.Average(ts => ts.TotalMilliseconds), 0);

            lock (_lock)
            {
                Console.Write($"[{this._partitionId}] Received {eventCount} events in {events.Count()} batch(es).");
                Console.Write($"\tBatch (From/To): {batchFrom.ToString("HH:mm:ss.ffffff")}/{batchTo.ToString("HH:mm:ss.ffffff")}");
                Console.Write($"\tElapsed msec (Min/Max/Avg): {minLatency}/{maxLatency}/{avgLatency}");
                Console.WriteLine();

                _csvOutput.WriteLine($"{this._partitionId},{events.Count()},{eventCount},{batchFrom.ToString("o")},{batchTo.ToString("o")},{minLatency},{maxLatency},{avgLatency}");
            }

            return Task.CompletedTask;
        }
    }

    public class EventReceiver
    {
        public async Task Receive(string connectionString, CancellationTokenSource cancellationSource)
        {
            Console.WriteLine("The application will now start to listen for incoming message.");

            var csvOutput = File.CreateText("./result.csv");
            csvOutput.WriteLine("PartitionId,EventCount,BatchCount,BatchFrom,BatchTo,MinLatency,MaxLatency,AvgLatency");

            await using (var consumerClient = new EventHubConsumerClient(EventHubConsumerClient.DefaultConsumerGroupName, connectionString))
            {
                string[] partitions = await consumerClient.GetPartitionIdsAsync();

                ReadEventOptions readOptions = new ReadEventOptions
                {
                    MaximumWaitTime = TimeSpan.FromMilliseconds(150)
                };

                cancellationSource.CancelAfter(TimeSpan.FromSeconds(60));

                List<EventData> receivedEvents = new List<EventData>();

                foreach (string partitionId in partitions)
                {
                    var myPartitionReceiver = new MyPartitionReceiver(partitionId, csvOutput);
                    int eventBatchSize = myPartitionReceiver.MaxBatchSize;

                    Console.WriteLine("Receive events from partion '{0}'.", partitionId);

                    await foreach (PartitionEvent currentEvent in consumerClient.ReadEventsFromPartitionAsync(partitionId, EventPosition.FromEnqueuedTime(DateTime.UtcNow), readOptions, cancellationSource.Token))
                    {
                        if (currentEvent.Data != null)
                        {
                            receivedEvents.Add(currentEvent.Data);

                            if (receivedEvents.Count >= eventBatchSize)
                            {
                                break;
                            }
                        }
                    }

                    await myPartitionReceiver.ProcessEventsAsync(receivedEvents);
                }
            }
        }
    }

    public class Program
    {
        static async Task Main(string[] args)
        {
            Options options = null;

            var result = Parser.Default.ParseArguments<Options>(args)
                .WithParsed(opts =>
                {
                    options = opts;
                });

            if (options == null) return;

            var check = new string[] { options.EventHubConnectionString };

            if (check.Where(e => string.IsNullOrEmpty(e)).ToList().Count() != 0)
            {
                Console.WriteLine("No parameters passed or environment variables set.");
                Console.WriteLine("Please use --help to learn how to use the application.");
                Console.WriteLine("  dotnet run -- --help");
                return;
            }

            var receiver = new EventReceiver();

            try
            {
                await receiver.Receive(options.EventHubConnectionString, new CancellationTokenSource());
            }
            catch (TaskCanceledException)
            {
                Console.WriteLine("Task is cancelled, exiting...");
            }

            Console.WriteLine("Done.");
        }

    }
}

using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Consumer;
using CommandLine;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace StreamingAtScale
{
    public class Options
    {
        [Option('c', "connectionString", Required = true, HelpText = "Event Hub connection string. It must be a Event Hub (not Namespace!) connection string.")]
        public string EventHubConnectionString { get; set; }
    }

    class ReceiverProcessor
    {
        private readonly object _lock = new object();
        private readonly StreamWriter _csvOutput = null;

        public ReceiverProcessor(StreamWriter csvOutput)
        {
            this._csvOutput = csvOutput;
        }

        public async Task ProcessEventsAsync(IAsyncEnumerable<PartitionEvent> events)
        {
            await foreach (PartitionEvent currentEvent in events)
            { 
                await ProcessEventsAsync(currentEvent);
            }
        }

        public Task ProcessEventsAsync(PartitionEvent item)
        {
            var eventData = item.Data;
            
            if (eventData == null) return Task.CompletedTask;
            int eventCount = 0;
            var listTS = new List<TimeSpan>();
            var listDT = new List<DateTimeOffset>();
            
            var eventBody = Encoding.UTF8.GetString(eventData.Body.ToArray()).Split('\n');

            foreach (var b in eventBody)
            {
                try
                {
                    var message = JsonSerializer.Deserialize<Dictionary<string, object>>(b);
                    eventCount += 1;

                    var timeCreated = DateTime.Parse(message["createdAt"].ToString());
                    var timeIn = DateTime.Parse(message["EventEnqueuedUtcTime"].ToString());
                    var timeProcessed = DateTime.Parse(message["EventProcessedUtcTime"].ToString());
                    var timeASAProcessed = DateTime.Parse(message["ASAProcessedUtcTime"].ToString());
                    var timeOut = eventData.EnqueuedTime.UtcDateTime.ToLocalTime();

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

            var batchFrom = listDT.Min();
            var batchTo = listDT.Min();
            var minLatency = listTS.Min().TotalMilliseconds;
            var maxLatency = listTS.Max().TotalMilliseconds;
            var avgLatency = Math.Round(listTS.Average(ts => ts.TotalMilliseconds), 0);

            lock (_lock)
            {
                Console.Write($"Received {eventCount} events.");
                Console.Write($"\tBatch (From/To): {batchFrom.ToString("HH:mm:ss.ffffff")}/{batchTo.ToString("HH:mm:ss.ffffff")}");
                Console.Write($"\tElapsed msec (Min/Max/Avg): {minLatency}/{maxLatency}/{avgLatency}");
                Console.WriteLine();

                _csvOutput.WriteLine($"{eventCount},{eventCount},{batchFrom.ToString("o")},{batchTo.ToString("o")},{minLatency},{maxLatency},{avgLatency}");
            }
            return Task.CompletedTask;

        }
    }

    public class EventReceiver
    {
        public async Task Receive(string connectionString, CancellationToken _cancellationToken)
        {
            await using (var consumerClient = new EventHubConsumerClient(EventHubConsumerClient.DefaultConsumerGroupName, connectionString))
            {
                Console.WriteLine("The application will now start to listen for incoming message.");

                ReadEventOptions readOptions = new ReadEventOptions
                {
                    MaximumWaitTime = TimeSpan.FromMilliseconds(150)
                };

                var csvOutput = File.CreateText("./resulttest.csv");
                csvOutput.WriteLine("EventCount,BatchCount,BatchFrom,BatchTo,MinLatency,MaxLatency,AvgLatency");
                try
                {
                    var events = consumerClient.ReadEventsAsync(startReadingAtEarliestEvent: false, readOptions, _cancellationToken);
                    var receiverProcessor = new ReceiverProcessor(csvOutput);
                    await receiverProcessor.ProcessEventsAsync(events);
                }
                catch (TaskCanceledException)
                {
                    // This is okay because the task was cancelled. :)
                }
                finally
                {
                    csvOutput.Close();
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
                Console.WriteLine("dotnet run -- --help");
                return;
            }

            using CancellationTokenSource cancellationSource = new CancellationTokenSource();
            cancellationSource.CancelAfter(TimeSpan.FromSeconds(60));
            var reciver = new EventReceiver();
            await reciver.Receive(options.EventHubConnectionString, cancellationSource.Token);

            Console.WriteLine("Done.");
        }
    }
}

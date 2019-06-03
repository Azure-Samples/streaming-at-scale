using System;
using System.Threading;
using System.Threading.Tasks;
using System.Linq;
using CommandLine;
using Microsoft.Azure.EventHubs;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.IO;
using System.Text;

namespace StreamingAtScale
{
    public class Options
    {
        [Option('c', "connectionString", Required = true, HelpText = "Event Hub connection string. It must be a Event Hub (not Namespace!) connection string.")]
        public string EventHubConnectionString { get; set; }
    }

    class MyPartitionReceiver : IPartitionReceiveHandler
    {
        private readonly object _lock = new object();
        private readonly string _partitionId = string.Empty;
        private readonly StreamWriter _csvOutput = null;
        private int _maxBatchSize = 1;

        public int MaxBatchSize { get => _maxBatchSize; set => _maxBatchSize = value; }

        public MyPartitionReceiver(string partitionId, StreamWriter csvOutput)
        {
            this._partitionId = partitionId;
            this._csvOutput = csvOutput;
        }

        public Task ProcessErrorAsync(Exception error)
        {
            Console.WriteLine(error.Message);
            return Task.FromException(error);
        }

        public Task ProcessEventsAsync(IEnumerable<EventData> events)
        {
            int eventCount = 0;

            var listTS = new List<TimeSpan>();
            var listDT = new List<DateTimeOffset>();

            foreach (var e in events)
            {
                var eventBody = Encoding.UTF8.GetString(e.Body.Array).Split('\n');

                foreach (var b in eventBody)
                {
                    try
                    {
                        var message = JsonConvert.DeserializeObject<JObject>(b, new JsonSerializerSettings() { DateParseHandling = DateParseHandling.None } );
                        eventCount += 1;

                        var timeCreated = DateTime.Parse(message["createdAt"].ToString());
                        var timeIn = DateTime.Parse(message["EventEnqueuedUtcTime"].ToString());
                        var timeProcessed = DateTime.Parse(message["EventProcessedUtcTime"].ToString());
                        var timeASAProcessed = DateTime.Parse(message["ASAProcessedUtcTime"].ToString());
                        var timeOut = e.SystemProperties.EnqueuedTimeUtc.ToLocalTime();

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

            lock(_lock) {
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
        private readonly EventHubClient _client;
        private CancellationToken _cancellationToken;

        public EventReceiver(string connectionString, CancellationToken _cancellationToken)
        {
            this._client = EventHubClient.CreateFromConnectionString(connectionString);

            this._cancellationToken = _cancellationToken;
        }

        public async Task Receive()
        {
            Console.WriteLine("The application will now start to listen for incoming message.");

            var csvOutput = File.CreateText("./result.csv");
            csvOutput.WriteLine("PartitionId,EventCount,BatchCount,BatchFrom,BatchTo,MinLatency,MaxLatency,AvgLatency");            

            var runtimeInfo = await _client.GetRuntimeInformationAsync();
            Console.WriteLine("Creating receiver handlers...");
            var utcNow = DateTime.UtcNow;
            var receivers = runtimeInfo.PartitionIds
                .Select(pid => {
                    var receiver = _client.CreateReceiver("$Default", pid, EventPosition.FromEnqueuedTime(utcNow));
                    Console.WriteLine("Created receiver for partition '{0}'.", pid);
                    receiver.SetReceiveHandler(new MyPartitionReceiver(pid, csvOutput));
                    return receiver;
                })
                .ToList();

            try
            {
                await Task.Delay(-1, this._cancellationToken);
            }
            catch (TaskCanceledException)
            {
                // This is okay because the task was cancelled. :)
            }
            finally
            {
                // Clean up nicely.
                await Task.WhenAll(
                    receivers.Select(receiver => receiver.CloseAsync())
                );
            }

            csvOutput.Close();
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

            var cts = new CancellationTokenSource();
            var receiver = new EventReceiver(options.EventHubConnectionString, cts.Token);
            
            Task t = receiver.Receive();

            Console.ReadKey(true);
            cts.Cancel();

            Console.WriteLine("Exiting...");
            await t;

            Console.WriteLine("Done.");      
        }
    
    }
}


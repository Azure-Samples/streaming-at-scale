using Azure.Messaging.EventHubs.Consumer;
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
    public class EventReceiver
    {
        private readonly object _lock = new object();

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

                    await foreach (PartitionEvent currentEvent in events)
                    {
                        var eventData = currentEvent.Data;
                        if (eventData == null) continue;
                        int eventCount = 0;
                        var listTimeSpan = new List<TimeSpan>();
                        var listDateTime = new List<DateTimeOffset>();

                        var eventBody = Encoding.UTF8.GetString(eventData.Body.ToArray()).Split('\n');

                        foreach (var bodyInfo in eventBody)
                        {
                            try
                            {
                                var message = JsonSerializer.Deserialize<Dictionary<string, object>>(bodyInfo);
                                eventCount += 1;

                                var timeCreated = DateTime.Parse(message["createdAt"].ToString());
                                var timeIn = DateTime.Parse(message["EventEnqueuedUtcTime"].ToString());
                                var timeProcessed = DateTime.Parse(message["EventProcessedUtcTime"].ToString());
                                var timeAsaProcessed = DateTime.Parse(message["ASAProcessedUtcTime"].ToString());
                                var timeOut = eventData.EnqueuedTime.UtcDateTime.ToLocalTime();

                                listDateTime.Add(timeIn);
                                var elapsed = timeOut - timeIn;
                                listTimeSpan.Add(elapsed);
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine("Error while parsing event body.");
                                Console.WriteLine("Error:" + ex.Message);
                                Console.WriteLine("Message:" + bodyInfo);
                            }
                        }

                        var batchFrom = listDateTime.Min();
                        var batchTo = listDateTime.Min();
                        var minLatency = listTimeSpan.Min().TotalMilliseconds;
                        var maxLatency = listTimeSpan.Max().TotalMilliseconds;
                        var avgLatency = Math.Round(listTimeSpan.Average(ts => ts.TotalMilliseconds), 0);

                        lock (_lock)
                        {
                            Console.Write($"Received {eventCount} events.");
                            Console.Write($"\tBatch (From/To): {batchFrom.ToString("HH:mm:ss.ffffff")}/{batchTo.ToString("HH:mm:ss.ffffff")}");
                            Console.Write($"\tElapsed msec (Min/Max/Avg): {minLatency}/{maxLatency}/{avgLatency}");
                            Console.WriteLine();

                            csvOutput.WriteLine($"{eventCount},{eventCount},{batchFrom.ToString("o")},{batchTo.ToString("o")},{minLatency},{maxLatency},{avgLatency}");
                        }
                    }
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
}

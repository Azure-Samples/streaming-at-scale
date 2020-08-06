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
        public async Task Receive(string connectionString, CancellationToken cancellationToken)
        {
            // In here, our consumer will read from the latest position instead of the earliest.  As a result, it won't see events that
            // have previously been published. 
            //
            // Each partition of an Event Hub represents a potentially infinite stream of events.  When a consumer is reading, there is no definitive
            // point where it can assess that all events have been read and no more will be available.  As a result, when the consumer reaches the end of
            // the available events for a partition, it will continue to wait for new events to arrive so that it can surface them to be processed. During this
            // time, the iterator will block.
            //
            // In order to prevent the consumer from waiting forever for events, and blocking other code, there is a method available for developers to
            // control this behavior. It's signaling the cancellation token passed when reading will cause the consumer to stop waiting and end iteration
            // immediately.  This is desirable when you have decided that you are done reading and do not wish to continue.  

            await using (var consumerClient = new EventHubConsumerClient(EventHubConsumerClient.DefaultConsumerGroupName, connectionString))
            {
                Console.WriteLine("The application will now start to listen for incoming message.");

                // Each time the consumer looks to read events, we'll ask that it waits only a short time before emitting
                // an empty event, so that our code has the chance to run without indefinite blocking.

                ReadEventOptions readOptions = new ReadEventOptions
                {
                    MaximumWaitTime = TimeSpan.FromMilliseconds(500)
                };

                using (var csvOutput = File.CreateText("./result.csv"))
                {
                    csvOutput.WriteLine("EventCount,BatchCount,BatchFrom,BatchTo,MinLatency,MaxLatency,AvgLatency");
                    try
                    {
                        // The client is safe and intended to be long-lived.

                        await foreach (PartitionEvent currentEvent in consumerClient.ReadEventsAsync(readOptions, cancellationToken))
                        {
                            var eventData = currentEvent.Data;

                            // Because publishing and receiving events is asynchronous, the events that published may not
                            // be immediately available for our consumer to see, so we'll have to guard against an empty event being sent
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
                                    eventCount++;

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

                            Console.Write($"Received {eventCount} events.");
                            Console.Write($"\tBatch (From/To): {batchFrom.ToString("HH:mm:ss.ffffff")}/{batchTo.ToString("HH:mm:ss.ffffff")}");
                            Console.Write($"\tElapsed msec (Min/Max/Avg): {minLatency}/{maxLatency}/{avgLatency}");
                            Console.WriteLine();

                            csvOutput.WriteLine($"{eventCount},{eventCount},{batchFrom.ToString("o")},{batchTo.ToString("o")},{minLatency},{maxLatency},{avgLatency}");
                        }
                    }
                    catch (TaskCanceledException)
                    {
                        // This is okay because the task was cancelled.
                    }
                }
            }
            // At this point, our clients have passed their "using" scope and have safely been disposed of.  We
            // have no further obligations.
        }
    }
}

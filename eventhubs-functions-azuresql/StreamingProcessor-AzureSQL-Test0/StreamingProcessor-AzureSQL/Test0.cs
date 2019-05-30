using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using System;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Text;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Microsoft.Azure.EventHubs;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Dapper;

namespace StreamingProcessor
{
    public static class Test0
    {
        private static readonly SqlConnection _conn = new SqlConnection(Environment.GetEnvironmentVariable("AzureSQLConnectionString"));

        /*
         * TDB
         */
        [FunctionName("Test0")]
        public static async Task RunAsync(
            [EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup = "%ConsumerGroup%")] EventData[] eventHubData,
            ILogger log)
        {
            var tasks = new List<Task>();

            Stopwatch sw = new Stopwatch();
            sw.Start();

            foreach (var data in eventHubData)
            {
                try
                {
                    string message = Encoding.UTF8.GetString(data.Body.Array);

                    var procedureParams = new
                    {
                        @eventId = message["eventId"],
                        @complexData = message["complexData"].ToString(),
                        @value = decimal.Parse(message["value"]),
                        @deviceId = message["deviceId"],
                        @type = message["type"],
                        @createdAt = message["createdAt"],
                        @enqueuedAt = data.SystemProperties.EnqueuedTimeUtc,
                        @processedAt = DateTime.UtcNow,
                        @partitionId = int.Parse(data.SystemProperties.PartitionKey)
                    };

                    tasks.Add(_conn.ExecuteAsync("stp_WriteData", procedureParams, commandType: CommandType.StoredProcedure));

                }
                catch (Exception ex)
                {
                    log.LogError($"{ex} - {ex.Message}");
                }
            }

            await Task.WhenAll(tasks);

            sw.Stop();

            string logMessage = $"[Test0] T:{eventHubData.Length} doc - E:{sw.ElapsedMilliseconds} msec";
            if (eventHubData.Length > 0)
            {
                logMessage += Environment.NewLine + $"AVG:{(sw.ElapsedMilliseconds / eventHubData.Length):N3} msec";
            }

            log.LogInformation(logMessage);
        }
    }

}

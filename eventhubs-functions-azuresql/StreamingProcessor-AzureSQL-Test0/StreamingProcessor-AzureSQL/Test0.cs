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

            var procedureName = Environment.GetEnvironmentVariable("AzureSQLProcedureName");

            foreach (var data in eventHubData)
            {
                try
                {
                    var conn = new SqlConnection(Environment.GetEnvironmentVariable("AzureSQLConnectionString"));

                    string message = Encoding.UTF8.GetString(data.Body.Array);                    
                    var json = JsonConvert.DeserializeObject<JObject>(message, new JsonSerializerSettings() { DateParseHandling = DateParseHandling.None } );
                    var cd = JObject.Parse(json["complexData"].ToString());                    
                    tasks.Add(conn.ExecuteAsync(procedureName, 
                        new {
                            @eventId = json["eventId"].ToString(),
                            @complexData = cd.ToString(),
                            @value = decimal.Parse(json["value"].ToString()),
                            @deviceId = json["deviceId"].ToString(),
                            @type = json["type"].ToString(),
                            @createdAt = json["createdAt"].ToString(),
                            @enqueuedAt = data.SystemProperties.EnqueuedTimeUtc,
                            @processedAt = DateTime.UtcNow//,
                            //@partitionId = Math.Abs(json["deviceId"].ToString().GetHashCode() % 16)
                        }, 
                        commandType: CommandType.StoredProcedure)
                    );

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
                logMessage += $" - AVG:{(sw.ElapsedMilliseconds / eventHubData.Length):N3} msec";
            }

            log.LogInformation(logMessage);
        }
    }

}

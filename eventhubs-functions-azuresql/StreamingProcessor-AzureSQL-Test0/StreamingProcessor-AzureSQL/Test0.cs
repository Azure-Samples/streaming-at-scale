using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using System;
using System.Data;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Text;
using System.Collections.Generic;
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
        [FunctionName("Test0")]
        public static async Task RunAsync(
            [EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup = "%ConsumerGroup%")] EventData[] eventHubData,
            ILogger log)
        {
            var payload = new DataTable("PayloadType");
            payload.Columns.Add("eventId", typeof(string));
            payload.Columns.Add("complexData", typeof(string));
            payload.Columns.Add("value", typeof(decimal));
            payload.Columns.Add("deviceId", typeof(string));
            payload.Columns.Add("type", typeof(string));
            payload.Columns.Add("createdAt", typeof(string));
            payload.Columns.Add("enqueuedAt", typeof(DateTime));
            payload.Columns.Add("processedAt", typeof(DateTime));

            Stopwatch sw = new Stopwatch();
            sw.Start();

            var procedureName = Environment.GetEnvironmentVariable("AzureSQLProcedureName");

            foreach (var data in eventHubData)
            {
                string message = Encoding.UTF8.GetString(data.Body.Array);                    
                var json = JsonConvert.DeserializeObject<JObject>(message, new JsonSerializerSettings() { DateParseHandling = DateParseHandling.None } );                

                payload.Rows.Add(
                    json["eventId"].ToString(),
                    JsonConvert.SerializeObject(JObject.Parse(json["complexData"].ToString()), Formatting.None),
                    decimal.Parse(json["value"].ToString()),
                    json["deviceId"].ToString(),
                    json["type"].ToString(),
                    json["createdAt"].ToString(),
                    data.SystemProperties.EnqueuedTimeUtc,
                    DateTime.UtcNow                        
                );
            }

            try
            {
                var conn = new SqlConnection(Environment.GetEnvironmentVariable("AzureSQLConnectionString"));
                await conn.ExecuteAsync(procedureName, new { @payload = payload.AsTableValuedParameter() }, commandType: CommandType.StoredProcedure);
            }
            catch (Exception ex)
            {
                log.LogError($"{ex} - {ex.Message}");
            }

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

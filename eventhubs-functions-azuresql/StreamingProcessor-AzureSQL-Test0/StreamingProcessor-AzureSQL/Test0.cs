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
using Microsoft.Azure.EventHubs.Processor;

namespace StreamingProcessor
{
    public static class Test0
    {
        [FunctionName("Test0")]
        public static async Task RunAsync(
            [EventHubTrigger("%EventHubName%", Connection = "EventHubsConnectionString", ConsumerGroup = "%ConsumerGroup%")] EventData[] eventHubData, 
            PartitionContext partitionContext, 
            ILogger log)
        {
            var procedureName = Environment.GetEnvironmentVariable("AzureSQLProcedureName");
            var payloadName = "payloadType" + (procedureName.EndsWith("_mo") ? "_mo" : "");

            var payload = new DataTable(payloadName);
            payload.Columns.Add("EventId", typeof(string));
            payload.Columns.Add("ComplexData", typeof(string));
            payload.Columns.Add("Value", typeof(decimal));
            payload.Columns.Add("DeviceId", typeof(string));
            payload.Columns.Add("Type", typeof(string));
            payload.Columns.Add("CreatedAt", typeof(string));
            payload.Columns.Add("EnqueuedAt", typeof(DateTime));
            payload.Columns.Add("ProcessedAt", typeof(DateTime));
            payload.Columns.Add("PartitionId", typeof(int));

            Stopwatch sw = new Stopwatch();
            sw.Start();            

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
                    DateTime.UtcNow,
                    partitionContext.RuntimeInformation.PartitionId
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

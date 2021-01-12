namespace ModelGenerator
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using System.Threading.Tasks;
    using Azure.Core;
    using Azure.Identity;
    using Microsoft.Azure.TimeSeriesInsights;
    using Microsoft.Azure.TimeSeriesInsights.Models;
    using Microsoft.Extensions.Logging;
    using Microsoft.Rest;
    using Microsoft.Rest.Serialization;
    using Newtonsoft.Json;

    class Program
    {
        private const int NumTwins = 1000;
        private const string TimeSeriesInsightsApplicationId = "120d688d-1518-4cf7-bd38-182f158850b6";

        private static readonly JsonSerializerSettings DeserializationSettings = new JsonSerializerSettings
        {
            Converters = new JsonConverter[]
            {
                new PolymorphicDeserializeJsonConverter<Variable>("kind"),
            }
        };

        private readonly ILogger<Program> _log;
        private readonly string _timeSeriesTypesFile;
        private readonly string _timeSeriesHierarchiesFile;
        private readonly TimeSeriesInsightsClient _timeSeriesInsightsClient;

        private Program(ILogger<Program> log,
            string timeSeriesTypesFile, string timeSeriesHierarchiesFile,
            TimeSeriesInsightsClient timeSeriesInsightsClient)
        {
            _log = log;
            _timeSeriesTypesFile = timeSeriesTypesFile;
            _timeSeriesHierarchiesFile = timeSeriesHierarchiesFile;
            _timeSeriesInsightsClient = timeSeriesInsightsClient;
        }

        static async Task Main(string[] args)
        {
            using var loggerFactory = LoggerFactory.Create(builder =>
            {
                builder
                    .AddFilter("Microsoft", LogLevel.Warning)
                    .AddFilter("System", LogLevel.Warning)
                    .AddFilter(typeof(Program).Namespace, LogLevel.Information)
                    .AddConsole();
            });
            var log = loggerFactory.CreateLogger<Program>()!;

            if (args.Length != 3)
            {
                throw new ArgumentException(
                    "Pass three parameters:"
                    + " <Azure Time Series Insights environment FQDN>"
                    + " <time_series_insights_types_file.json>"
                    + " <time_series_insights_hierarchies_file.json>"
                );
            }

            var ( timeSeriesEnvironmentFqdn, timeSeriesTypesFile, timeSeriesHierarchiesFile)
                = (args[0], args[1], args[2]);

            //Authenticate with Digital Twins
            var credentialsOptions = new DefaultAzureCredentialOptions
            {
                ExcludeVisualStudioCodeCredential = true,
                ExcludeSharedTokenCacheCredential = true,
                ExcludeInteractiveBrowserCredential = true,
                ExcludeEnvironmentCredential = true,
                ExcludeVisualStudioCredential = true
            };
            var credential = new DefaultAzureCredential(credentialsOptions);
            var timeSeriesInsightsClient =
                await GetTimeSeriesInsightsClientAsync(credential, timeSeriesEnvironmentFqdn);

            try
            {
                var program = new Program(
                    log,
                    timeSeriesTypesFile,
                    timeSeriesHierarchiesFile,
                    timeSeriesInsightsClient);
                await program.RunAsync();
            }
            catch (Exception e)
            {
                log.LogError("{message}", e.Message, e);
            }
        }

        async Task RunAsync()
        {
            var timeSeriesHierarchies = await CreateTimeSeriesHierarchiesAsync();
            var timeSeriesTypes = await CreateTimeSeriesTypesAsync();
            await CreateTimeSeriesInstancesAsync(timeSeriesHierarchies, timeSeriesTypes);
        }

        private async Task<List<TimeSeriesHierarchy>> CreateTimeSeriesHierarchiesAsync()
        {
            var hierarchies = JsonConvert.DeserializeObject<List<TimeSeriesHierarchy>>(
                                  await File.ReadAllTextAsync(_timeSeriesHierarchiesFile),
                                  DeserializationSettings)
                              ?? throw new ArgumentException($"No hierarchies found in {_timeSeriesHierarchiesFile}");
            
            _log.LogInformation("Creating {n} hierarchies", hierarchies.Count);
            
            var createHierarchiesResponse = await
                _timeSeriesInsightsClient.TimeSeriesHierarchies.ExecuteBatchWithHttpMessagesAsync(
                    new HierarchiesBatchRequest(put: hierarchies));
            CheckErrors(createHierarchiesResponse, createHierarchiesResponse.Body.Put.Select(_ => _.Error));
            return hierarchies;
        }

        private async Task<List<TimeSeriesType>> CreateTimeSeriesTypesAsync()
        {
            var timeSeriesTypes = JsonConvert.DeserializeObject<List<TimeSeriesType>>(
                                      await File.ReadAllTextAsync(_timeSeriesTypesFile),
                                      DeserializationSettings)
                                  ?? throw new ArgumentException(
                                      $"No types found in {_timeSeriesTypesFile}");
            
            _log.LogInformation("Creating {n} types", timeSeriesTypes.Count);
            
            var createTypesResponse =
                await _timeSeriesInsightsClient.TimeSeriesTypes.ExecuteBatchWithHttpMessagesAsync(
                    new TypesBatchRequest(put: timeSeriesTypes));
            CheckErrors(createTypesResponse, createTypesResponse.Body.Put.Select(_ => _.Error));
            return timeSeriesTypes;
        }

        private async Task CreateTimeSeriesInstancesAsync(List<TimeSeriesHierarchy> hierarchies,
            List<TimeSeriesType> types)
        {
            var timeSeriesInstances =
                Enumerable.Range(0, NumTwins)
                    .Select(i =>
                        new TimeSeriesInstance(
                            new object[] {$"contoso-device-id-{i.ToString("000000")}"},
                            types.First().Id,
                            $"Device #{i}",
                            "A simulated device",
                            hierarchies.Select(_ => _.Id).ToList(),
                            new Dictionary<string, object>()
                            {
                                {"year", 2020},
                                {"month", i % 12 + 1},
                                {"vehicle", i % 2 == 0 ? "Car" : "Bus"},
                            })
                    ).ToList();

            _log.LogInformation("Creating {n} instances", timeSeriesInstances.Count);
            
            InstancesBatchRequest req = new InstancesBatchRequest(put: timeSeriesInstances);
            var createInstancesResponse =
                await _timeSeriesInsightsClient.TimeSeriesInstances.ExecuteBatchWithHttpMessagesAsync(req);
            CheckErrors(createInstancesResponse, createInstancesResponse.Body.Put.Select(_ => _.Error));
        }

        private static void CheckErrors(HttpOperationResponse operationResponse, IEnumerable<TsiErrorBody> errorBodies)
        {
            if (errorBodies.Any(IsError))
            {
                throw new InvalidOperationException(operationResponse.Response.AsFormattedString());
            }
        }

        private static bool IsError(TsiErrorBody? errorBody)
        {
            return errorBody != null;
        }

        private static async Task<TimeSeriesInsightsClient> GetTimeSeriesInsightsClientAsync(
            TokenCredential credential, string timeSeriesEnvironmentFqdn)
        {
            var token = await credential.GetTokenAsync(
                new TokenRequestContext(new[] {TimeSeriesInsightsApplicationId}), default);
            ServiceClientCredentials clientCredentials = new TokenCredentials(token.Token);

            TimeSeriesInsightsClient timeSeriesInsightsClient = new TimeSeriesInsightsClient(clientCredentials)
            {
                EnvironmentFqdn = timeSeriesEnvironmentFqdn
            };
            return timeSeriesInsightsClient;
        }
    }
}

namespace ModelGenerator
{
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using System.Net.Http;
    using System.Threading;
    using System.Threading.Tasks;
    using Azure;
    using Azure.Core;
    using Azure.Core.Pipeline;
    using Azure.DigitalTwins.Core;
    using Azure.Identity;
    using Microsoft.Azure.DigitalTwins.Parser;
    using Microsoft.Azure.TimeSeriesInsights;
    using Microsoft.Azure.TimeSeriesInsights.Models;
    using Microsoft.Extensions.Logging;
    using Microsoft.Rest;
    using Microsoft.Rest.Serialization;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Linq;

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
        private readonly TokenCredential _credential;
        private readonly Uri _digitalTwinsInstanceUrl;
        private readonly string _digitalTwinsModelsFile;
        private readonly string _timeSeriesTypesFile;
        private readonly string _timeSeriesHierarchiesFile;
        private readonly TimeSeriesInsightsClient _timeSeriesInsightsClient;

        private Program(ILogger<Program> log, TokenCredential credential, Uri digitalTwinsInstanceUrl,
            string digitalTwinsModelsFile, string timeSeriesTypesFile, string timeSeriesHierarchiesFile,
            TimeSeriesInsightsClient timeSeriesInsightsClient)
        {
            _log = log;
            _credential = credential;
            _digitalTwinsInstanceUrl = digitalTwinsInstanceUrl;
            _digitalTwinsModelsFile = digitalTwinsModelsFile;
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

            if (args.Length != 5)
            {
                throw new ArgumentException(
                    "Pass five parameters:"
                    + " <Azure Digital Twins Instance URL>"
                    + " <Azure Time Series Insights environment FQDN>"
                    + " <digital_twins_models_file.json>"
                    + " <time_series_insights_types_file.json>"
                    + " <time_series_insights_hierarchies_file.json>"
                );
            }

            var (digitalTwinsInstanceUrl,
                    timeSeriesEnvironmentFqdn,
                    digitalTwinsModelsFile,
                    timeSeriesTypesFile,
                    timeSeriesHierarchiesFile)
                = (args[0], args[1], args[2], args[3], args[4]);

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
                    credential,
                    new Uri(digitalTwinsInstanceUrl),
                    digitalTwinsModelsFile,
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
            await PopulateTimeSeriesInsights();
            await PopulateDigitalTwins();
        }

        async Task PopulateDigitalTwins()
        {
            var httpClient = new HttpClient();
            var digitalTwinsClient = new DigitalTwinsClient(_digitalTwinsInstanceUrl, _credential,
                new DigitalTwinsClientOptions {Transport = new HttpClientTransport(httpClient)});

            _log.LogInformation("Reading model file {modelsFile}", _digitalTwinsModelsFile);
            var modelList = new[] {_digitalTwinsModelsFile}.Select(File.ReadAllText).ToList();
            var parser = new ModelParser();
            var parsed = await parser.ParseAsync(modelList);

            _log.LogInformation("Parsed {entityCount} entities", parsed.Keys.Count());

            var models = modelList
                .SelectMany(JsonConvert.DeserializeObject<List<JObject>>)
                .ToList();

            var (successCount, conflictCount) = (0, 0);
            foreach (var model in models)
            {
                var modelString = JsonConvert.SerializeObject(model);
                try
                {
                    await digitalTwinsClient.CreateModelsAsync(new[] {modelString});
                    successCount++;
                }
                catch (RequestFailedException e) when (e.Status == 409) // Conflict
                {
                    // ignore
                    conflictCount++;
                }
            }

            _log.LogInformation("Uploaded {successCount} entities, skipped {conflictCount} entities", successCount,
                conflictCount);

            var f = models.FirstOrDefault()?.GetValue("@id");
            if (f is null)
            {
                _log.LogInformation("Not creating twins");
                return;
            }

            DigitalTwinMetadata twinMetadata = new DigitalTwinMetadata
                {ModelId = f.ToString()};
            _log.LogInformation("Creating {numTwins} device twins of type {twinType}", NumTwins, twinMetadata.ModelId);

            var num = 0;
            Parallel.For(0, NumTwins, new ParallelOptions
            {
                MaxDegreeOfParallelism = 50
            }, i =>
            {
                var deviceId = $"contoso-device-id-{i}";
                digitalTwinsClient.CreateOrReplaceDigitalTwin(deviceId, new BasicDigitalTwin
                {
                    Metadata = twinMetadata
                });

                _log.LogDebug("Created twin {deviceId}", deviceId);
                var n = Interlocked.Increment(ref num);
                if (n % 100 == 0)
                {
                    _log.LogInformation("Created twin {n} of {numTwins}", n, NumTwins);
                }
            });
            _log.LogInformation("Created {numTwins} twins", NumTwins);
        }

        private async Task PopulateTimeSeriesInsights()
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
            var createTypesResponse =
                await _timeSeriesInsightsClient.TimeSeriesTypes.ExecuteBatchWithHttpMessagesAsync(
                    new TypesBatchRequest(put: timeSeriesTypes));
            CheckErrors(createTypesResponse, createTypesResponse.Body.Put.Select(_ => _.Error));
            return timeSeriesTypes;
        }

        private async Task CreateTimeSeriesInstancesAsync(List<TimeSeriesHierarchy> hierarchies,
            List<TimeSeriesType> types)
        {
            var put =
                Enumerable.Range(0, NumTwins)
                    .Select(i =>
                        new TimeSeriesInstance(
                            new object[] {$"contoso-device-id-{i}"},
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
            InstancesBatchRequest req = new InstancesBatchRequest(put: put);
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
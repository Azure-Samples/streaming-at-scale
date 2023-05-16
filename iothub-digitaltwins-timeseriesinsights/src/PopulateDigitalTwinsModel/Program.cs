namespace PopulateDigitalTwinsModel
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
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;
    using Newtonsoft.Json.Linq;

    class Program
    {
        private const int NumTwins = 1000;

        private readonly ILogger<Program> _log;
        private readonly TokenCredential _credential;
        private readonly Uri _digitalTwinsInstanceUrl;
        private readonly string _digitalTwinsModelsFile;

        private Program(ILogger<Program> log, TokenCredential credential, Uri digitalTwinsInstanceUrl,
            string digitalTwinsModelsFile)
        {
            _log = log;
            _credential = credential;
            _digitalTwinsInstanceUrl = digitalTwinsInstanceUrl;
            _digitalTwinsModelsFile = digitalTwinsModelsFile;
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

            if (args.Length != 2)
            {
                throw new ArgumentException(
                    "Pass two parameters:"
                    + " <Azure Digital Twins Instance URL>"
                    + " <digital_twins_models_file.json>"
                );
            }

            var (digitalTwinsInstanceUrl, digitalTwinsModelsFile)
                = (args[0], args[1]);

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

            try
            {
                var program = new Program(
                    log,
                    credential,
                    new Uri(digitalTwinsInstanceUrl),
                    digitalTwinsModelsFile);
                await program.RunAsync();
            }
            catch (Exception e)
            {
                log.LogError("{message}", e.Message, e);
            }
        }

        async Task RunAsync()
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
                var deviceId = $"contoso-device-id-{i.ToString("000000")}";
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
    }
}

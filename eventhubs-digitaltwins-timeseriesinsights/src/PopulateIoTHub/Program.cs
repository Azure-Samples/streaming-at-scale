namespace PopulateIoTHub
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using System.Threading.Tasks;
    using Microsoft.Azure.Devices;
    using Microsoft.Azure.Devices.Common.Exceptions;
    using Microsoft.Extensions.Logging;

    class Program
    {
        private const int NumTwins = 1000;
        
        /// <summary>
        /// Maximum number of devices accepted by <see cref="RegistryManager.AddDevices2Async(IEnumerable{Device})"/>
        /// </summary>
        private const int MaxBatchSize = 100;

        private readonly ILogger<Program> _log;
        private readonly string _connectionString;

        private Program(ILogger<Program> log, string connectionString)
        {
            _log = log;
            _connectionString = connectionString;
        }

        static async Task Main()
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

            try
            {
                var connectionString = Environment.GetEnvironmentVariable("CONNECTION_STRING") ??
                                       throw new InvalidOperationException(
                                           "Please set environment variable CONNECTION_STRING");
                var program = new Program(log, connectionString);
                await program.RunAsync();
            }
            catch (Exception e)
            {
                log.LogError("{message}", e.Message, e);
            }
        }

        async Task RunAsync()
        {
            var registryManager = RegistryManager.CreateFromConnectionString(_connectionString);
            await registryManager.OpenAsync();

            for (int i = 0; i < NumTwins; i += MaxBatchSize)
            {
                var count = Math.Min(NumTwins - i, MaxBatchSize);
                var devices =
                        Enumerable.Range(i, count)
                            .Select(_ => new Device($"contoso-device-id-{_.ToString("000000")}")) ;
                _log
                    .LogInformation("Provisioning {n} devices starting at #{i}", count, i);
                var bulkResult = await registryManager.AddDevices2Async(devices);

                var error = bulkResult
                    .Errors
                    .FirstOrDefault(_ => _.ErrorCode != ErrorCode.DeviceAlreadyExists);
                if (error is {})
                {
                    throw new Exception(error.ErrorStatus);
                }
            }
        }
    }
}
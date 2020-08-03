using CommandLine;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace StreamingAtScale
{
    public class Options
    {
        [Option('c', "connectionString", Required = true, HelpText = "Event Hub connection string. It must be a Event Hub (not Namespace!) connection string.")]
        public string EventHubConnectionString { get; set; }
    }

    public class Program
    {
        static async Task Main(string[] args)
        {
            Options options = null;

            var result = Parser.Default.ParseArguments<Options>(args)
                .WithParsed(opts =>
                {
                    options = opts;
                });

            if (options == null) return;

            var check = new string[] { options.EventHubConnectionString };

            if (check.Where(e => string.IsNullOrEmpty(e)).ToList().Count() != 0)
            {
                Console.WriteLine("No parameters passed or environment variables set.");
                Console.WriteLine("Please use --help to learn how to use the application.");
                Console.WriteLine("dotnet run -- --help");
                return;
            }

            using CancellationTokenSource cancellationSource = new CancellationTokenSource();
            cancellationSource.CancelAfter(TimeSpan.FromSeconds(60));
            var receiver = new EventReceiver();
            await receiver.Receive(options.EventHubConnectionString, cancellationSource.Token);

            Console.WriteLine("Done.");
        }
    }
}

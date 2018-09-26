using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Client;
using System.Threading;

namespace StreamingProcessor
{
    public class CosmosDBClient
    {
        private static CosmosDBClient _instance = null;
        static SemaphoreSlim semaphoreSlim = new SemaphoreSlim(1, 1);

        private readonly DocumentClient _client = null;
        private readonly Uri _collectionLink = null;

        private CosmosDBClient(DocumentClient client, Uri collectionLink)
        {
            _client = client;
            _collectionLink = collectionLink;
        }

        private static async Task<CosmosDBClient> CreateInstance()
        {
            string connectionString = Environment.GetEnvironmentVariable("CosmosDBConnectionString");
            string[] parts = connectionString.Split(';');
            string endpoint = parts[0].Replace("AccountEndpoint=", "");
            string accountKey = parts[1].Replace("AccountKey=", "");

            var serviceEndpoint = new Uri(endpoint);
            var authKey = accountKey;

            var client = new DocumentClient(serviceEndpoint, authKey,
                new ConnectionPolicy
                {
                    ConnectionMode = ConnectionMode.Direct,
                    ConnectionProtocol = Protocol.Tcp
                });

            var database = new Database { Id = Environment.GetEnvironmentVariable("CosmosDBDatabaseName") };
            var databaseItem = await client.CreateDatabaseIfNotExistsAsync(database);
            var databaseLink = UriFactory.CreateDatabaseUri(database.Id);

            var collection = new DocumentCollection { Id = Environment.GetEnvironmentVariable("CosmosDBCollectionName") };
            var collectionItem = await client.CreateDocumentCollectionIfNotExistsAsync(databaseLink, collection);
            var collectionLink = UriFactory.CreateDocumentCollectionUri(database.Id, collection.Id);

            return new CosmosDBClient(client, collectionLink);
        }

        public static async Task<CosmosDBClient> GetClient()
        {
            await semaphoreSlim.WaitAsync();
            try
            {
                if (_instance == null)
                {
                    _instance = await CreateInstance();
                }
            } finally
            {
                semaphoreSlim.Release();
            }

            return _instance;
        }

        public async Task<ResourceResponse<Document>> CreateDocumentAsync(object payload)
        {
            return await _client.CreateDocumentAsync(_collectionLink, payload);
        }
    }
}

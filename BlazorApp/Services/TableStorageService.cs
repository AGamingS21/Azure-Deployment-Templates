using Azure.Core.Diagnostics;
using Azure.Data.Tables;
using Azure.Identity;
using BlazorApp.Models;

namespace BlazorApp.Services
{
    public class TableStorageService
    {
        private TableServiceClient _tableServiceClient {get; set;}
        public TableStorageService(string uri)
        {
            _tableServiceClient = new TableServiceClient(new Uri(uri), new DefaultAzureCredential());
        }


        public async void CreateTestData(string tableName)
        {
            //await _tableServiceClient.DeleteTableAsync(tableName);

            // Create the table if it does not exist
            var tableClient = await GetTableClient(tableName);

            await tableClient.CreateIfNotExistsAsync();

            Random random = new Random();

            

            // Insert test data
            var testEntity = new TableEntity(random.Next().ToString(), random.Next().ToString())
            {
                {"Name", "Test Name"},
                {"Value", "Test Value"}
            };
            await tableClient.AddEntityAsync(testEntity);
        }

        public async Task<TableClient> GetTableClient(string tableName)
        {
            return _tableServiceClient.GetTableClient(tableName);
        }

        public async Task<List<TestEntity>> GetEntitiesAsync(string tableName)
        {
            var tableClient = await GetTableClient(tableName);
            var entities = new List<TestEntity>();
            await foreach (var page in tableClient.QueryAsync<TestEntity>().AsPages())
            {
                entities.AddRange(page.Values);
            }
            return entities;
        }

        // Do the create table if exists method as a test.
    }
}
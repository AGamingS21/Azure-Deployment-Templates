using Azure;
using Azure.Data.Tables;

namespace BlazorApp.Models
{

public class TestEntity : ITableEntity
{
    public string? PartitionKey { get; set; }
    public string? RowKey { get; set; }
    public string? Data { get; set; }
    public DateTimeOffset? Timestamp { get; set; }
    public ETag ETag { get; set; }
}

}
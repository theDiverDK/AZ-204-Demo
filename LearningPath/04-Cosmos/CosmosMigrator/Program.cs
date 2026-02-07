using System.Text.Json;
using Microsoft.Azure.Cosmos;

if (args.Length != 5)
{
    Console.Error.WriteLine("Usage: CosmosMigrator <sessionsJsonPath> <endpoint> <key> <databaseName> <sessionsContainerName>");
    return 1;
}

var sessionsJsonPath = args[0];
var endpoint = args[1];
var key = args[2];
var databaseName = args[3];
var sessionsContainerName = args[4];

if (!File.Exists(sessionsJsonPath))
{
    Console.Error.WriteLine($"ERROR: Sessions JSON file not found: {sessionsJsonPath}");
    return 1;
}

var json = await File.ReadAllTextAsync(sessionsJsonPath);
var sessions = JsonSerializer.Deserialize<List<SourceSession>>(json, new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true
}) ?? new List<SourceSession>();

using var cosmosClient = new CosmosClient(endpoint, key);
var container = cosmosClient.GetContainer(databaseName, sessionsContainerName);

var nextId = 1;
var migrated = 0;

foreach (var session in sessions)
{
    if (session.Id <= 0)
    {
        session.Id = nextId;
    }

    session.CurrentRegistrations = 0;

    var document = new Dictionary<string, object?>
    {
        ["id"] = session.Id.ToString(),
        ["Id"] = session.Id,
        ["Title"] = session.Title,
        ["Speaker"] = session.Speaker,
        ["StartTime"] = session.StartTime,
        ["EndTime"] = session.EndTime,
        ["Room"] = session.Room,
        ["Description"] = session.Description,
        ["Capacity"] = session.Capacity,
        ["CurrentRegistrations"] = session.CurrentRegistrations
    };

    await container.UpsertItemAsync(document, new PartitionKey(session.Id.ToString()));

    nextId = Math.Max(nextId, session.Id + 1);
    migrated++;
}

Console.WriteLine($"Migrated {migrated} session(s) to Cosmos DB container '{sessionsContainerName}'.");
return 0;

internal sealed class SourceSession
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Speaker { get; set; } = string.Empty;
    public DateTime StartTime { get; set; }
    public DateTime EndTime { get; set; }
    public string Room { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public int Capacity { get; set; }
    public int CurrentRegistrations { get; set; }
}

using System.Text.Json;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using ConferenceHub.Models;
using Microsoft.Extensions.Options;

namespace ConferenceHub.Services
{
    public interface IEventTelemetryService
    {
        Task TrackAsync(string eventName, object payload);
    }

    public class EventTelemetryService : IEventTelemetryService
    {
        private readonly EventHubConfig _config;
        private readonly ILogger<EventTelemetryService> _logger;

        public EventTelemetryService(IOptions<EventHubConfig> config, ILogger<EventTelemetryService> logger)
        {
            _config = config.Value;
            _logger = logger;
        }

        public async Task TrackAsync(string eventName, object payload)
        {
            if (string.IsNullOrWhiteSpace(_config.ConnectionString) || string.IsNullOrWhiteSpace(_config.HubName))
            {
                _logger.LogInformation("EventHub telemetry is not configured. Skipping event {EventName}", eventName);
                return;
            }

            try
            {
                await using var producer = new EventHubProducerClient(_config.ConnectionString, _config.HubName);
                using var batch = await producer.CreateBatchAsync();

                var envelope = new
                {
                    eventName,
                    timestampUtc = DateTime.UtcNow,
                    payload
                };

                var message = JsonSerializer.Serialize(envelope);
                if (!batch.TryAdd(new EventData(message)))
                {
                    _logger.LogWarning("Event payload too large for Event Hub batch: {EventName}", eventName);
                    return;
                }

                await producer.SendAsync(batch);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send event telemetry for {EventName}", eventName);
            }
        }
    }
}

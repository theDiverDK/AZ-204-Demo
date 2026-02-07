using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace ConferenceHub.Functions;

public sealed class SlideUploadedEventFunction
{
    private readonly ILogger<SlideUploadedEventFunction> _logger;

    public SlideUploadedEventFunction(ILogger<SlideUploadedEventFunction> logger)
    {
        _logger = logger;
    }

    [Function("SlideUploadedEvent")]
    public void Run([EventGridTrigger] string eventGridEvent)
    {
        _logger.LogInformation("Received Event Grid slide upload event: {EventPayload}", eventGridEvent);
    }
}

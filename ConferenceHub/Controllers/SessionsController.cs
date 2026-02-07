using ConferenceHub.Models;
using ConferenceHub.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Options;
using System.Security.Claims;
using System.Text;
using System.Text.Json;

namespace ConferenceHub.Controllers
{
    public class SessionsController : Controller
    {
        private readonly IDataService _dataService;
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly AzureFunctionsConfig _functionsConfig;
        private readonly IEventTelemetryService _eventTelemetryService;
        private readonly string _apiMode;
        private readonly string _functionsBaseUrl;
        private readonly ILogger<SessionsController> _logger;

        public SessionsController(
            IDataService dataService,
            IEventTelemetryService eventTelemetryService,
            IHttpClientFactory httpClientFactory,
            IOptions<AzureFunctionsConfig> functionsConfig,
            IConfiguration configuration,
            ILogger<SessionsController> logger)
        {
            _dataService = dataService;
            _eventTelemetryService = eventTelemetryService;
            _httpClientFactory = httpClientFactory;
            _functionsConfig = functionsConfig.Value;
            _apiMode = (configuration["API_MODE"] ?? "none").Trim().ToLowerInvariant();
            _functionsBaseUrl = (configuration["FUNCTIONS_BASE_URL"] ?? string.Empty).Trim().TrimEnd('/');
            _logger = logger;
        }

        // GET: Sessions
        public async Task<IActionResult> Index()
        {
            var sessions = await _dataService.GetSessionsAsync();
            await _eventTelemetryService.TrackAsync("sessions.list.viewed", new
            {
                totalSessions = sessions.Count,
                user = User.Identity?.Name
            });
            return View(sessions);
        }

        // GET: Sessions/Details/5
        public async Task<IActionResult> Details(int id)
        {
            var session = await _dataService.GetSessionByIdAsync(id);
            if (session == null)
            {
                return NotFound();
            }

            await _eventTelemetryService.TrackAsync("session.details.viewed", new
            {
                sessionId = session.Id,
                sessionTitle = session.Title,
                user = User.Identity?.Name
            });
            return View(session);
        }

        // POST: Sessions/Register
        [HttpPost]
        [Authorize]
        public async Task<IActionResult> Register(int sessionId)
        {
            var session = await _dataService.GetSessionByIdAsync(sessionId);
            if (session == null)
            {
                return NotFound();
            }

            var attendeeName = User.FindFirst("name")?.Value
                ?? User.Identity?.Name
                ?? "Unknown attendee";

            var attendeeEmail = User.FindFirst(ClaimTypes.Email)?.Value
                ?? User.FindFirst("preferred_username")?.Value
                ?? User.Identity?.Name
                ?? "unknown@local";

            if (session.CurrentRegistrations >= session.Capacity)
            {
                TempData["Error"] = "This session is at full capacity.";
                return RedirectToAction(nameof(Details), new { id = sessionId });
            }

            var registration = new Registration
            {
                SessionId = sessionId,
                AttendeeName = attendeeName,
                AttendeeEmail = attendeeEmail
            };

            await _dataService.AddRegistrationAsync(registration);
            await _eventTelemetryService.TrackAsync("session.registration.created", new
            {
                sessionId = session.Id,
                sessionTitle = session.Title,
                attendeeEmail,
                attendeeName
            });

            TempData["Success"] = "Successfully registered for the session!";

            // Call Azure Function at the end of registration flow
            await SendConfirmationEmailAsync(session, attendeeName, attendeeEmail);

            return RedirectToAction(nameof(Details), new { id = sessionId });
        }

        private async Task SendConfirmationEmailAsync(Session session, string attendeeName, string attendeeEmail)
        {
            try
            {
                if (_apiMode == "none")
                {
                    _logger.LogInformation("API_MODE=none. Skipping confirmation call for {Email}", attendeeEmail);
                    return;
                }

                var client = _httpClientFactory.CreateClient();

                var registrationRequest = new
                {
                    sessionId = session.Id,
                    sessionTitle = session.Title,
                    attendeeName = attendeeName,
                    attendeeEmail = attendeeEmail,
                    sessionStartTime = session.StartTime,
                    room = session.Room
                };

                var json = JsonSerializer.Serialize(registrationRequest);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var url = _functionsConfig.SendConfirmationUrl;
                if (_apiMode == "functions" && !string.IsNullOrWhiteSpace(_functionsBaseUrl))
                {
                    url = $"{_functionsBaseUrl}/api/SendConfirmation";
                }

                if (string.IsNullOrWhiteSpace(url))
                {
                    _logger.LogWarning("No function URL configured. Skipping confirmation call.");
                    return;
                }

                if (!string.IsNullOrEmpty(_functionsConfig.FunctionKey))
                {
                    url += $"?code={_functionsConfig.FunctionKey}";
                }

                var response = await client.PostAsync(url, content);

                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Confirmation email sent successfully for {Email}", attendeeEmail);
                }
                else
                {
                    _logger.LogWarning("Failed to send confirmation email. Status: {Status}", response.StatusCode);
                }
            }
            catch (Exception ex)
            {
                // Don't fail the registration if email fails
                _logger.LogError(ex, "Error calling SendConfirmation function");
            }
        }
    }
}

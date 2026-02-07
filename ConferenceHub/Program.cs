using ConferenceHub.Services;
using ConferenceHub.Models;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.Identity.Web;
using Microsoft.Identity.Web.UI;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services
    .AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApp(builder.Configuration.GetSection("AzureAd"));

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("OrganizerOnly", policy =>
    {
        policy.RequireAuthenticatedUser();
        policy.RequireRole("Organizer");
    });
});

builder.Services
    .AddControllersWithViews()
    .AddMicrosoftIdentityUI();

builder.Services.Configure<CosmosDbConfig>(
    builder.Configuration.GetSection("CosmosDb"));
builder.Services.AddSingleton<IDataService, CosmosDataService>();
builder.Services.Configure<SlideStorageConfig>(
    builder.Configuration.GetSection("SlideStorage"));
builder.Services.AddSingleton<ISlideStorageService, SlideStorageService>();
builder.Services.Configure<EventHubConfig>(
    builder.Configuration.GetSection("EventHub"));
builder.Services.AddSingleton<IEventTelemetryService, EventTelemetryService>();

// Configure Azure Functions settings
builder.Services.Configure<AzureFunctionsConfig>(
    builder.Configuration.GetSection("AzureFunctions"));

// Add HttpClient for calling Azure Functions
builder.Services.AddHttpClient();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

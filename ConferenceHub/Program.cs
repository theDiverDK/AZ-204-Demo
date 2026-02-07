using ConferenceHub.Services;
using ConferenceHub.Models;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();
builder.Services.Configure<CosmosDbConfig>(
    builder.Configuration.GetSection("CosmosDb"));
builder.Services.AddSingleton<IDataService, CosmosDataService>();
builder.Services.Configure<SlideStorageConfig>(
    builder.Configuration.GetSection("SlideStorage"));
builder.Services.AddSingleton<ISlideStorageService, SlideStorageService>();

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

app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.Run();

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$project_dir = "$repo_root/ConferenceHub"
$publish_dir = "$project_dir/publish"
$package_path = "$project_dir/app.zip"
$cosmos_endpoint = ""
$cosmos_key = ""
# LP4 assumes LP1, LP2 and LP3 are already completed.
# Create new Cosmos resources and update existing Web App settings.
az cosmosdb create  --name "$cosmos_account_name"  --resource-group "$resource_group_name"  --locations regionName="$location" failoverPriority=0 isZoneRedundant=False  --default-consistency-level Session
az cosmosdb sql database create  --account-name "$cosmos_account_name"  --resource-group "$resource_group_name"  --name "$cosmos_database_name"
az cosmosdb sql container create  --account-name "$cosmos_account_name"  --resource-group "$resource_group_name"  --database-name "$cosmos_database_name"  --name "$cosmos_sessions_container_name"  --partition-key-path "$cosmos_sessions_partition_key"  --throughput 400
az cosmosdb sql container create  --account-name "$cosmos_account_name"  --resource-group "$resource_group_name"  --database-name "$cosmos_database_name"  --name "$cosmos_registrations_container_name"  --partition-key-path "$cosmos_registrations_partition_key"  --throughput 400
$cosmos_endpoint = "$(az cosmosdb show  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query `"documentEndpoint`"  -o tsv)"
$cosmos_key = "$(az cosmosdb keys list  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query `"primaryMasterKey`"  -o tsv)"
az webapp config appsettings set  --resource-group "$resource_group_name"  --name "$web_app_name"  --settings  ASPNETCORE_ENVIRONMENT=Development  WEBSITE_RUN_FROM_PACKAGE=1  API_MODE=functions  FUNCTIONS_BASE_URL="https://$function_app_name.azurewebsites.net"  CosmosDb__Endpoint="$cosmos_endpoint"  CosmosDb__Key="$cosmos_key"  CosmosDb__DatabaseName="$cosmos_database_name"  CosmosDb__SessionsContainerName="$cosmos_sessions_container_name"  CosmosDb__RegistrationsContainerName="$cosmos_registrations_container_name"
# --------------------
dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$publish_dir"
if (Test-Path "$package_path") { Remove-Item -Force "$package_path" }
Push-Location "$publish_dir"
try {
    if (Test-Path "$package_path") { Remove-Item -Force "$package_path" }
    Compress-Archive -Path (Join-Path "$publish_dir" '*') -DestinationPath "$package_path" -Force
} finally {
    Pop-Location
}
az webapp deploy  --resource-group "$resource_group_name"  --name "$web_app_name"  --src-path "$package_path"  --type zip
az webapp browse  --resource-group "$resource_group_name"  --name "$web_app_name"

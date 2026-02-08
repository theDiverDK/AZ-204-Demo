$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$data_file = "$repo_root/ConferenceHub/Data/sessions.json"
$migrator_project = "$script_dir/CosmosMigrator/CosmosMigrator.csproj"
if (-not (Test-Path -LiteralPath $data_file -PathType Leaf)) {
    Write-Host "ERROR: Sessions seed file not found: $data_file"
    exit 1
}
$cosmos_endpoint = "$(az cosmosdb show  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query `"documentEndpoint`"  -o tsv)"
$cosmos_key = "$(az cosmosdb keys list  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query `"primaryMasterKey`"  -o tsv)"
dotnet run --project "$migrator_project" --  "$data_file"  "$cosmos_endpoint"  "$cosmos_key"  "$cosmos_database_name"  "$cosmos_sessions_container_name"
Write-Host "Migration complete. Sessions inserted into Cosmos."

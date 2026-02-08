$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$project_dir = "$repo_root/ConferenceHub"
$publish_dir = "$project_dir/publish"
$package_path = "$project_dir/app.zip"
$slides_storage_key = ""
$slides_storage_connection_string = ""
# LP3 assumes LP1 and LP2 are already completed.
# Create only new Storage resources for session slide upload.
az storage account create  --name "$slides_storage_account_name"  --resource-group "$resource_group_name"  --location "$location"  --sku "$slides_storage_sku"  --kind StorageV2  --allow-blob-public-access true  --min-tls-version TLS1_2
az storage account update  --name "$slides_storage_account_name"  --resource-group "$resource_group_name"  --allow-blob-public-access true
$slides_storage_key = "$(az storage account keys list  --resource-group `"$resource_group_name`"  --account-name `"$slides_storage_account_name`"  --query `"[0].value`"  -o tsv)"
az storage container create  --name "$slides_container_name"  --account-name "$slides_storage_account_name"  --account-key "$slides_storage_key"  --public-access blob
$container_exists = "$(az storage container exists  --name `"$slides_container_name`"  --account-name `"$slides_storage_account_name`"  --account-key `"$slides_storage_key`"  --query `"exists`"  -o tsv)"
if ($container_exists -ne "true") {
    Write-Host "ERROR: Storage container '$slides_container_name' was not created in account '$slides_storage_account_name'."
    exit 1
}
Write-Host "Storage container '$slides_container_name' is ready in account '$slides_storage_account_name'."
$slides_storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=$slides_storage_account_name;AccountKey=$slides_storage_key;EndpointSuffix=core.windows.net"
az webapp config appsettings set  --resource-group "$resource_group_name"  --name "$web_app_name"  --settings  ASPNETCORE_ENVIRONMENT=Production  WEBSITE_RUN_FROM_PACKAGE=1  SlideStorage__ConnectionString="$slides_storage_connection_string"  SlideStorage__ContainerName="$slides_container_name"
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

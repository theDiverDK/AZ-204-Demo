$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$project_dir = "$repo_root/ConferenceHub"
$web_publish_dir = "$project_dir/publish"
$web_package_path = "$project_dir/app.zip"
$functions_project_path = "$repo_root/$functions_project_dir/$functions_project_name.csproj"
$functions_publish_path = "$repo_root/$functions_publish_dir"
$functions_zip_path = "$repo_root/$functions_package_path"
$functions_base_url = "https://$function_app_name.azurewebsites.net"
$functions_send_url = "$functions_base_url/api/SendConfirmation"
$function_key = ""
# LP2 assumes LP1 already created RG/App Service Plan/Web App.
# Only create new Function resources, then update/deploy existing apps.
az storage account create  --name "$storage_account_name"  --resource-group "$resource_group_name"  --location "$location"  --sku Standard_LRS  --kind StorageV2  --min-tls-version TLS1_2
az functionapp create  --name "$function_app_name"  --resource-group "$resource_group_name"  --consumption-plan-location "$location"  --storage-account "$storage_account_name"  --functions-version 4  --runtime "$function_runtime"  --runtime-version "$function_runtime_version"
az functionapp config set  --resource-group "$resource_group_name"  --name "$function_app_name"  --min-tls-version 1.2
az webapp config set  --resource-group "$resource_group_name"  --name "$web_app_name"  --min-tls-version 1.2
az functionapp config appsettings set  --resource-group "$resource_group_name"  --name "$function_app_name"  --settings  FUNCTIONS_WORKER_RUNTIME="$function_worker_runtime"  CONFIRMATION_SENDER_EMAIL="$confirmation_sender_email"
# --------------------
dotnet publish "$functions_project_path" -c Release -o "$functions_publish_path"
if (Test-Path "$functions_zip_path") { Remove-Item -Force "$functions_zip_path" }
Push-Location "$functions_publish_path"
try {
    if (Test-Path "$functions_zip_path") { Remove-Item -Force "$functions_zip_path" }
    Compress-Archive -Path (Join-Path "$functions_publish_path" '*') -DestinationPath "$functions_zip_path" -Force
} finally {
    Pop-Location
}
az functionapp deployment source config-zip  --resource-group "$resource_group_name"  --name "$function_app_name"  --src "$functions_zip_path"
$function_key = "$(az functionapp keys list  --resource-group `"$resource_group_name`"  --name `"$function_app_name`"  --query `"functionKeys.$function_key_name`"  -o tsv)"
az webapp config appsettings set  --resource-group "$resource_group_name"  --name "$web_app_name"  --settings  ASPNETCORE_ENVIRONMENT=Production  WEBSITE_RUN_FROM_PACKAGE=1  API_MODE=functions  FUNCTIONS_BASE_URL="$functions_base_url"  AzureFunctions__SendConfirmationUrl="$functions_send_url"  AzureFunctions__FunctionKey="$function_key"
# --------------------
dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$web_publish_dir"
if (Test-Path "$web_package_path") { Remove-Item -Force "$web_package_path" }
Push-Location "$web_publish_dir"
try {
    if (Test-Path "$web_package_path") { Remove-Item -Force "$web_package_path" }
    Compress-Archive -Path (Join-Path "$web_publish_dir" '*') -DestinationPath "$web_package_path" -Force
} finally {
    Pop-Location
}
az webapp deploy  --resource-group "$resource_group_name"  --name "$web_app_name"  --src-path "$web_package_path"  --type zip
az webapp browse  --resource-group "$resource_group_name"  --name "$web_app_name"

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
# shellcheck source=/dev/null
. "$repo_root/tools/common.ps1"
if ([string]::IsNullOrEmpty($random)) { $random = "49152" }
$random = $random
if ([string]::IsNullOrEmpty($location)) { $location = "swedencentral" }
$location = $location
if ([string]::IsNullOrEmpty($resource_group_name)) { $resource_group_name = "rg-conferencehub" }
$resource_group_name = $resource_group_name
if ([string]::IsNullOrEmpty($app_service_plan_name)) { $app_service_plan_name = "plan-conferencehub" }
$app_service_plan_name = $app_service_plan_name
$web_app_name = "${web_app_name:-app-conferencehub-$random}"
if ([string]::IsNullOrEmpty($app_service_plan_sku)) { $app_service_plan_sku = "P0V3" }
$app_service_plan_sku = $app_service_plan_sku
if ([string]::IsNullOrEmpty($runtime)) { $runtime = "DOTNETCORE:9.0" }
$runtime = $runtime
$project_dir = "$repo_root/ConferenceHub"
$publish_dir = "$project_dir/publish"
$package_path = "$project_dir/app.zip"
require_base_tools
require_az_login
ensure_resource_group "$resource_group_name" "$location"
ensure_app_service_plan "$app_service_plan_name" "$resource_group_name" "$location" "$app_service_plan_sku"
ensure_webapp "$web_app_name" "$resource_group_name" "$app_service_plan_name" "$runtime"
set_webapp_settings "$resource_group_name" "$web_app_name"  ASPNETCORE_ENVIRONMENT=Production  WEBSITE_RUN_FROM_PACKAGE=1  API_MODE=none  FUNCTIONS_BASE_URL=  AzureFunctions__SendConfirmationUrl=  AzureFunctions__FunctionKey=
publish_conferencehub "$project_dir" "$publish_dir"
zip_directory "$publish_dir" "$package_path"
deploy_webapp_zip "$resource_group_name" "$web_app_name" "$package_path"
browse_webapp "$resource_group_name" "$web_app_name"

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir '../..')).Path
. (Join-Path $repoRoot 'tools/variables.ps1')

if ([string]::IsNullOrEmpty($random)) { $random = '49152' }
if ([string]::IsNullOrEmpty($location)) { $location = 'swedencentral' }
if ([string]::IsNullOrEmpty($resource_group_name)) { $resource_group_name = 'rg-conferencehub' }
if ([string]::IsNullOrEmpty($app_service_plan_name)) { $app_service_plan_name = 'plan-conferencehub' }
if ([string]::IsNullOrEmpty($app_service_plan_sku)) { $app_service_plan_sku = 'P0V3' }
if ([string]::IsNullOrEmpty($web_app_name)) { $web_app_name = "app-conferencehub-$random" }
if ([string]::IsNullOrEmpty($runtime)) {
    if (-not [string]::IsNullOrEmpty($web_runtime)) {
        $runtime = $web_runtime
    } else {
        $runtime = 'DOTNETCORE:9.0'
    }
}

$projectDir = Join-Path $repoRoot 'ConferenceHub'
$publishDir = Join-Path $projectDir 'publish'
$packagePath = Join-Path $projectDir 'app.zip'

az group create --name $resource_group_name --location $location

az appservice plan show --name $app_service_plan_name --resource-group $resource_group_name *> $null
if ($LASTEXITCODE -ne 0) {
    az appservice plan create --name $app_service_plan_name --resource-group $resource_group_name --location $location --is-linux --sku $app_service_plan_sku
}

az webapp show --name $web_app_name --resource-group $resource_group_name *> $null
if ($LASTEXITCODE -ne 0) {
    az webapp create --name $web_app_name --resource-group $resource_group_name --plan $app_service_plan_name --runtime $runtime
}

az webapp config appsettings set --resource-group $resource_group_name --name $web_app_name --settings `
  ASPNETCORE_ENVIRONMENT=Production `
  WEBSITE_RUN_FROM_PACKAGE=1 `
  API_MODE=none `
  FUNCTIONS_BASE_URL= `
  AzureFunctions__SendConfirmationUrl= `
  AzureFunctions__FunctionKey=

dotnet publish (Join-Path $projectDir 'ConferenceHub.csproj') -c Release -o $publishDir

if (Test-Path -LiteralPath $packagePath) { Remove-Item -Force $packagePath }
Compress-Archive -Path (Join-Path $publishDir '*') -DestinationPath $packagePath -Force

az webapp deploy --resource-group $resource_group_name --name $web_app_name --src-path $packagePath --type zip

az webapp browse --resource-group $resource_group_name --name $web_app_name

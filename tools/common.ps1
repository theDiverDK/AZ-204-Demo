$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

function Log-Info([string]$Message) {
    Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message)
}

function Fail([string]$Message) {
    throw "ERROR: $Message"
}

function Require-Command([string]$CommandName) {
    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        Fail "Required command not found: $CommandName"
    }
}

function Require-BaseTools {
    Require-Command az
    Require-Command dotnet
}

function Require-AzLogin {
    az account show *> $null
}

function Ensure-ResourceGroup([string]$ResourceGroup, [string]$Location) {
    $exists = (az group exists --name $ResourceGroup -o tsv).Trim()
    if ($exists -eq 'true') {
        Log-Info "Resource group exists: $ResourceGroup"
    } else {
        Log-Info "Creating resource group: $ResourceGroup"
        az group create --name $ResourceGroup --location $Location *> $null
    }
}

function Ensure-AppServicePlan([string]$Plan, [string]$ResourceGroup, [string]$Location, [string]$Sku) {
    az appservice plan show --name $Plan --resource-group $ResourceGroup *> $null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "App Service plan exists: $Plan"
    } else {
        Log-Info "Creating App Service plan: $Plan"
        az appservice plan create --name $Plan --resource-group $ResourceGroup --location $Location --is-linux --sku $Sku *> $null
    }
}

function Ensure-WebApp([string]$App, [string]$ResourceGroup, [string]$Plan, [string]$Runtime) {
    az webapp show --name $App --resource-group $ResourceGroup *> $null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "Web App exists: $App"
    } else {
        Log-Info "Creating Web App: $App"
        az webapp create --name $App --resource-group $ResourceGroup --plan $Plan --runtime $Runtime *> $null
    }
}

function Ensure-StorageAccount([string]$Storage, [string]$ResourceGroup, [string]$Location, [string]$Sku) {
    az storage account show --name $Storage --resource-group $ResourceGroup *> $null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "Storage account exists: $Storage"
    } else {
        Log-Info "Creating storage account: $Storage"
        az storage account create --name $Storage --resource-group $ResourceGroup --location $Location --sku $Sku --kind StorageV2 *> $null
    }
}

function Ensure-FunctionApp([string]$App, [string]$ResourceGroup, [string]$Location, [string]$Storage, [string]$Runtime, [string]$RuntimeVersion) {
    az functionapp show --name $App --resource-group $ResourceGroup *> $null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "Function App exists: $App"
    } else {
        Log-Info "Creating Function App: $App"
        az functionapp create --name $App --resource-group $ResourceGroup --consumption-plan-location $Location --storage-account $Storage --functions-version 4 --runtime $Runtime --runtime-version $RuntimeVersion --os-type Linux *> $null
    }
}

function Set-WebAppSettings([string]$ResourceGroup, [string]$App, [string[]]$Settings) {
    az webapp config appsettings set --resource-group $ResourceGroup --name $App --settings $Settings *> $null
}

function Set-FunctionAppSettings([string]$ResourceGroup, [string]$App, [string[]]$Settings) {
    az functionapp config appsettings set --resource-group $ResourceGroup --name $App --settings $Settings *> $null
}

function Publish-ConferenceHub([string]$ProjectDir, [string]$PublishDir) {
    Log-Info 'Publishing ConferenceHub'
    dotnet publish (Join-Path $ProjectDir 'ConferenceHub.csproj') -c Release -o $PublishDir
}

function Zip-Directory([string]$SourceDir, [string]$PackagePath) {
    if (Test-Path -LiteralPath $PackagePath) {
        Remove-Item -Force $PackagePath
    }

    $sourceWildcard = Join-Path $SourceDir '*'
    Compress-Archive -Path $sourceWildcard -DestinationPath $PackagePath -Force
}

function Deploy-WebAppZip([string]$ResourceGroup, [string]$App, [string]$PackagePath) {
    Log-Info 'Deploying Web App package'
    az webapp deploy --resource-group $ResourceGroup --name $App --src-path $PackagePath --type zip *> $null
}

function Deploy-FunctionAppZip([string]$ResourceGroup, [string]$App, [string]$PackagePath) {
    Log-Info 'Deploying Function App package'
    az functionapp deployment source config-zip --resource-group $ResourceGroup --name $App --src $PackagePath *> $null
}

function Browse-WebApp([string]$ResourceGroup, [string]$App) {
    az webapp browse --resource-group $ResourceGroup --name $App
}

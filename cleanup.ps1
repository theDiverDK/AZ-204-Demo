$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'tools/variables.ps1')

$keyVaultName = "kv-conferencehub-$random"
$appConfigName = "appcs-conferencehub-$random"

Write-Host "Deleting resource group: $resource_group_name"
az group show --name $resource_group_name *> $null
if ($LASTEXITCODE -eq 0) {
    az group delete --name $resource_group_name --yes --no-wait *> $null
    Write-Host 'Waiting for resource group deletion to finish...'
    az group wait --name $resource_group_name --deleted *> $null
} else {
    Write-Host "Resource group '$resource_group_name' does not exist. Skipping delete."
}

Write-Host "Purging soft-deleted Key Vault (if present): $keyVaultName"
for ($attempt = 1; $attempt -le 30; $attempt++) {
    $deletedCount = (az keyvault list-deleted --query "[?name=='$keyVaultName'] | length(@)" -o tsv).Trim()
    if ($deletedCount -eq '1') {
        az keyvault purge --name $keyVaultName --location $location
        break
    }

    if ($attempt -eq 30) {
        Write-Host "Key Vault '$keyVaultName' was not found in soft-deleted state. Skipping purge."
        break
    }

    Write-Host "Key Vault not visible in deleted list yet (attempt $attempt/30). Waiting 10s..."
    Start-Sleep -Seconds 10
}

Write-Host "Purging soft-deleted App Configuration (if present): $appConfigName"
$appConfigDeletedCount = (az appconfig list-deleted --query "[?name=='$appConfigName'] | length(@)" -o tsv).Trim()
if ($appConfigDeletedCount -eq '1') {
    az appconfig purge --name $appConfigName --location $location --yes
}

Write-Host 'Cleanup complete.'

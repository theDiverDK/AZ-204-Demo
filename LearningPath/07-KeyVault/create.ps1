$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$current_user_id = ""
$app_id = ""
$key_vault_id = ""
$key_vault_existing_id = ""
$web_principal_id = ""
$role_assignment_id = ""
$cosmos_key = ""
$slides_storage_key = ""
$slides_storage_connection_string = ""
$function_key = ""
$entra_client_secret = ""
$current_user_id = "$(az ad signed-in-user show --query id -o tsv || true)"
$app_id = "$(az ad app list --display-name `"$entra_app_registration_name`" --query `"[0].appId`" -o tsv)"
if ([string]::IsNullOrEmpty($app_id)) {
    Write-Host "Could not find Entra app registration '$entra_app_registration_name'. Run LP6 first."
    exit 1
}
$key_vault_existing_id = "$(az keyvault show  --name `"$key_vault_name`"  --resource-group `"$resource_group_name`"  --query id  -o tsv 2>/dev/null || true)"
if ([string]::IsNullOrEmpty($key_vault_existing_id)) {
    az keyvault create  --name "$key_vault_name"  --resource-group "$resource_group_name"  --location "$location"  --sku "$key_vault_sku"  --enable-rbac-authorization true
}
az keyvault update  --name "$key_vault_name"  --resource-group "$resource_group_name"  --enable-rbac-authorization true
$key_vault_id = "$(az keyvault show --name `"$key_vault_name`" --resource-group `"$resource_group_name`" --query id -o tsv)"
if (-not [string]::IsNullOrEmpty($current_user_id)) {
    $role_assignment_id = "$(az role assignment list --assignee-object-id `"$current_user_id`" --scope `"$key_vault_id`" --role `"Key Vault Secrets Officer`" --query `"[0].id`" -o tsv || true)"
    if ([string]::IsNullOrEmpty($role_assignment_id)) {
        az role assignment create  --assignee-object-id "$current_user_id"  --assignee-principal-type User  --role "Key Vault Secrets Officer"  --scope "$key_vault_id"
    }
}
$cosmos_key = "$(az cosmosdb keys list  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query primaryMasterKey  -o tsv)"
$slides_storage_key = "$(az storage account keys list  --resource-group `"$resource_group_name`"  --account-name `"$slides_storage_account_name`"  --query `"[0].value`"  -o tsv)"
$slides_storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=$slides_storage_account_name;AccountKey=$slides_storage_key;EndpointSuffix=core.windows.net"
$function_key = "$(az functionapp keys list  --resource-group `"$resource_group_name`"  --name `"$function_app_name`"  --query `"functionKeys.$function_key_name`"  -o tsv || true)"
if ([string]::IsNullOrEmpty($function_key)) {
    $function_key = "$(az functionapp keys list  --resource-group `"$resource_group_name`"  --name `"$function_app_name`"  --query `"masterKey`"  -o tsv || true)"
}
$entra_client_secret = "$(az ad app credential reset  --id `"$app_id`"  --append  --display-name `"lp07-keyvault`"  --years 2  --query password -o tsv)"
az keyvault secret set  --vault-name "$key_vault_name"  --name "$kv_secret_azuread_client_secret_name"  --value "$entra_client_secret"
az keyvault secret set  --vault-name "$key_vault_name"  --name "$kv_secret_cosmos_key_name"  --value "$cosmos_key"
az keyvault secret set  --vault-name "$key_vault_name"  --name "$kv_secret_slides_connection_string_name"  --value "$slides_storage_connection_string"
az keyvault secret set  --vault-name "$key_vault_name"  --name "$kv_secret_functions_key_name"  --value "$function_key"
$web_principal_id = "$(az webapp identity assign  --resource-group `"$resource_group_name`"  --name `"$web_app_name`"  --query principalId  -o tsv)"
$role_assignment_id = ""
for ($attempt = 1; $attempt -le 12; $attempt++) {
    $role_assignment_id = "$(az role assignment list --assignee-object-id `"$web_principal_id`" --scope `"$key_vault_id`" --role `"Key Vault Secrets User`" --query `"[0].id`" -o tsv || true)"
    if (-not [string]::IsNullOrEmpty($role_assignment_id)) {
        break
    }
    az role assignment create  --assignee-object-id "$web_principal_id"  --assignee-principal-type ServicePrincipal  --role "Key Vault Secrets User"  --scope "$key_vault_id"
    if ($LASTEXITCODE -eq 0) {
        break
    }
    Write-Host "Waiting for web app managed identity to propagate (attempt $attempt/12)..."
    sleep 10
}
az webapp config appsettings set  --resource-group "$resource_group_name"  --name "$web_app_name"  --settings  AzureAd__ClientSecret="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_azuread_client_secret_name)"  CosmosDb__Key="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_cosmos_key_name)"  SlideStorage__ConnectionString="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_slides_connection_string_name)"  AzureFunctions__FunctionKey="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_functions_key_name)"
# Remove legacy plain-text secret setting names if they exist.
try {
    az webapp config appsettings delete  --resource-group "$resource_group_name"  --name "$web_app_name"  --setting-names  AzureAdClientSecret  CosmosDbKey  SlideStorageConnectionString  AzureFunctionsFunctionKey  FUNCTIONS_FUNCTION_KEY  COSMOS_KEY  SLIDES_STORAGE_CONNECTION_STRING
} catch {
}
az webapp restart  --resource-group "$resource_group_name"  --name "$web_app_name"
# Cleanup local secret variables from shell memory.
Remove-Variable cosmos_key -ErrorAction SilentlyContinue
Remove-Variable slides_storage_key -ErrorAction SilentlyContinue
Remove-Variable slides_storage_connection_string -ErrorAction SilentlyContinue
Remove-Variable function_key -ErrorAction SilentlyContinue
Remove-Variable entra_client_secret -ErrorAction SilentlyContinue
az webapp browse  --resource-group "$resource_group_name"  --name "$web_app_name"

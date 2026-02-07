#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

current_user_id=""
app_id=""
key_vault_id=""
key_vault_existing_id=""
web_principal_id=""
role_assignment_id=""
cosmos_key=""
slides_storage_key=""
slides_storage_connection_string=""
function_key=""
entra_client_secret=""

current_user_id="$(az ad signed-in-user show --query id -o tsv)"

app_id="$(az ad app list --display-name "$entra_app_registration_name" --query "[0].appId" -o tsv)"
if [[ -z "$app_id" ]]; then
  echo "Could not find Entra app registration '$entra_app_registration_name'. Run LP6 first."
  exit 1
fi

key_vault_existing_id="$(az keyvault show \
  --name "$key_vault_name" \
  --resource-group "$resource_group_name" \
  --query id \
  -o tsv 2>/dev/null || true)"

if [[ -z "$key_vault_existing_id" ]]; then
  az keyvault create \
    --name "$key_vault_name" \
    --resource-group "$resource_group_name" \
    --location "$location" \
    --sku "$key_vault_sku" \
    --enable-rbac-authorization true
fi

az keyvault update \
  --name "$key_vault_name" \
  --resource-group "$resource_group_name" \
  --enable-rbac-authorization true

key_vault_id="$(az keyvault show --name "$key_vault_name" --resource-group "$resource_group_name" --query id -o tsv)"

role_assignment_id="$(az role assignment list --assignee-object-id "$current_user_id" --scope "$key_vault_id" --role "Key Vault Secrets Officer" --query "[0].id" -o tsv)"
if [[ -z "$role_assignment_id" ]]; then
  az role assignment create \
    --assignee-object-id "$current_user_id" \
    --assignee-principal-type User \
    --role "Key Vault Secrets Officer" \
    --scope "$key_vault_id"
fi

cosmos_key="$(az cosmosdb keys list \
  --name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --query primaryMasterKey \
  -o tsv)"

slides_storage_key="$(az storage account keys list \
  --resource-group "$resource_group_name" \
  --account-name "$slides_storage_account_name" \
  --query "[0].value" \
  -o tsv)"

slides_storage_connection_string="DefaultEndpointsProtocol=https;AccountName=${slides_storage_account_name};AccountKey=${slides_storage_key};EndpointSuffix=core.windows.net"

function_key="$(az functionapp keys list \
  --resource-group "$resource_group_name" \
  --name "$function_app_name" \
  --query "functionKeys.${function_key_name}" \
  -o tsv)"

entra_client_secret="$(az ad app credential reset \
  --id "$app_id" \
  --append \
  --display-name "lp07-keyvault" \
  --years 2 \
  --query password -o tsv)"

az keyvault secret set \
  --vault-name "$key_vault_name" \
  --name "$kv_secret_azuread_client_secret_name" \
  --value "$entra_client_secret"

az keyvault secret set \
  --vault-name "$key_vault_name" \
  --name "$kv_secret_cosmos_key_name" \
  --value "$cosmos_key"

az keyvault secret set \
  --vault-name "$key_vault_name" \
  --name "$kv_secret_slides_connection_string_name" \
  --value "$slides_storage_connection_string"

az keyvault secret set \
  --vault-name "$key_vault_name" \
  --name "$kv_secret_functions_key_name" \
  --value "$function_key"

web_principal_id="$(az webapp identity assign \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --query principalId \
  -o tsv)"

role_assignment_id="$(az role assignment list --assignee-object-id "$web_principal_id" --scope "$key_vault_id" --role "Key Vault Secrets User" --query "[0].id" -o tsv)"
if [[ -z "$role_assignment_id" ]]; then
  az role assignment create \
    --assignee-object-id "$web_principal_id" \
    --assignee-principal-type ServicePrincipal \
    --role "Key Vault Secrets User" \
    --scope "$key_vault_id"
fi

az webapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --settings \
  AzureAd__ClientSecret="@Microsoft.KeyVault(VaultName=${key_vault_name};SecretName=${kv_secret_azuread_client_secret_name})" \
  CosmosDb__Key="@Microsoft.KeyVault(VaultName=${key_vault_name};SecretName=${kv_secret_cosmos_key_name})" \
  SlideStorage__ConnectionString="@Microsoft.KeyVault(VaultName=${key_vault_name};SecretName=${kv_secret_slides_connection_string_name})" \
  AzureFunctions__FunctionKey="@Microsoft.KeyVault(VaultName=${key_vault_name};SecretName=${kv_secret_functions_key_name})"

# Remove legacy plain-text secret setting names if they exist.
az webapp config appsettings delete \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --setting-names \
  AzureAdClientSecret \
  CosmosDbKey \
  SlideStorageConnectionString \
  AzureFunctionsFunctionKey \
  FUNCTIONS_FUNCTION_KEY \
  COSMOS_KEY \
  SLIDES_STORAGE_CONNECTION_STRING || true

az webapp restart \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

# Cleanup local secret variables from shell memory.
unset cosmos_key
unset slides_storage_key
unset slides_storage_connection_string
unset function_key
unset entra_client_secret

az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

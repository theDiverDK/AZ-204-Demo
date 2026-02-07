#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

subscription_id=""
key_vault_id=""
web_principal_id=""
role_assignment_id=""
eventhub_connection_string=""
storage_account_id=""
existing_subscription_name=""
function_resource_id=""
existing_namespace_name=""
existing_eventhub_name=""
existing_auth_rule_name=""

project_dir="$repo_root/ConferenceHub"
web_publish_dir="$repo_root/.deploy/lp09/web/publish"
web_package_path="$repo_root/.deploy/lp09/web/app.zip"

functions_project_path="$repo_root/$functions_project_dir/$functions_project_name.csproj"
functions_publish_path="$repo_root/.deploy/lp09/functions/publish"
functions_zip_path="$repo_root/.deploy/lp09/functions/functions.zip"

subscription_id="$(az account show --query id -o tsv)"

existing_namespace_name="$(az eventhubs namespace list \
  --resource-group "$resource_group_name" \
  --query "[?name=='${eventhub_namespace_name}'].name | [0]" \
  -o tsv)"

if [[ -z "$existing_namespace_name" ]]; then
  az eventhubs namespace create \
    --name "$eventhub_namespace_name" \
    --resource-group "$resource_group_name" \
    --location "$location" \
    --sku Standard
fi

existing_eventhub_name="$(az eventhubs eventhub list \
  --namespace-name "$eventhub_namespace_name" \
  --resource-group "$resource_group_name" \
  --query "[?name=='${eventhub_name}'].name | [0]" \
  -o tsv)"

if [[ -z "$existing_eventhub_name" ]]; then
  az eventhubs eventhub create \
    --name "$eventhub_name" \
    --namespace-name "$eventhub_namespace_name" \
    --resource-group "$resource_group_name"
fi

existing_auth_rule_name="$(az eventhubs namespace authorization-rule list \
  --namespace-name "$eventhub_namespace_name" \
  --resource-group "$resource_group_name" \
  --query "[?name=='${eventhub_auth_rule_name}'].name | [0]" \
  -o tsv)"

if [[ -z "$existing_auth_rule_name" ]]; then
  az eventhubs namespace authorization-rule create \
    --name "$eventhub_auth_rule_name" \
    --namespace-name "$eventhub_namespace_name" \
    --resource-group "$resource_group_name" \
    --rights Send
fi

eventhub_connection_string="$(az eventhubs namespace authorization-rule keys list \
  --name "$eventhub_auth_rule_name" \
  --namespace-name "$eventhub_namespace_name" \
  --resource-group "$resource_group_name" \
  --query primaryConnectionString \
  -o tsv)"

key_vault_id="$(az keyvault list \
  --resource-group "$resource_group_name" \
  --query "[?name=='${key_vault_name}'].id | [0]" \
  -o tsv)"

if [[ -z "$key_vault_id" ]]; then
  echo "Could not find Key Vault '$key_vault_name'. Run LP7 first."
  exit 1
fi

az keyvault secret set \
  --vault-name "$key_vault_name" \
  --name "$kv_secret_eventhub_connection_string_name" \
  --value "$eventhub_connection_string"

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
  EventHub__ConnectionString="@Microsoft.KeyVault(VaultName=${key_vault_name};SecretName=${kv_secret_eventhub_connection_string_name})" \
  EventHub__HubName="$eventhub_name"

az webapp config appsettings delete \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --setting-names \
  EventHubConnectionString \
  EVENTHUB_CONNECTION_STRING || true

# --------------------

rm -rf "$functions_publish_path"
mkdir -p "$functions_publish_path"

dotnet publish "$functions_project_path" -c Release -o "$functions_publish_path"

rm -f "$functions_zip_path"
(cd "$functions_publish_path" && zip -qr "$functions_zip_path" .)

az functionapp deployment source config-zip \
  --resource-group "$resource_group_name" \
  --name "$function_app_name" \
  --src "$functions_zip_path"

function_resource_id="/subscriptions/${subscription_id}/resourceGroups/${resource_group_name}/providers/Microsoft.Web/sites/${function_app_name}/functions/SlideUploadedEvent"
storage_account_id="$(az storage account show --name "$slides_storage_account_name" --resource-group "$resource_group_name" --query id -o tsv)"

existing_subscription_name="$(az eventgrid event-subscription list \
  --source-resource-id "$storage_account_id" \
  --query "[?name=='${eventgrid_subscription_name}'].name | [0]" \
  -o tsv)"

if [[ -z "$existing_subscription_name" ]]; then
  az eventgrid event-subscription create \
    --name "$eventgrid_subscription_name" \
    --source-resource-id "$storage_account_id" \
    --included-event-types Microsoft.Storage.BlobCreated \
    --subject-begins-with "/blobServices/default/containers/${slides_container_name}/blobs/" \
    --endpoint-type azurefunction \
    --endpoint "$function_resource_id"
fi

rm -rf "$web_publish_dir"
mkdir -p "$web_publish_dir"

dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$web_publish_dir"

rm -f "$web_package_path"
(cd "$web_publish_dir" && zip -qr "$web_package_path" .)

az webapp deploy \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --src-path "$web_package_path" \
  --type zip

az webapp restart \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

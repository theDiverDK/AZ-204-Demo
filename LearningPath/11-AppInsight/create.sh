#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

app_insights_name=""
app_insights_connection_string=""
container_app_exists=""
key_vault_uri=""

project_dir="$repo_root/ConferenceHub"
web_publish_dir="$repo_root/.deploy/lp11/web/publish"
web_package_path="$repo_root/.deploy/lp11/web/app.zip"

functions_project_path="$repo_root/$functions_project_dir/$functions_project_name.csproj"
functions_publish_path="$repo_root/.deploy/lp11/functions/publish"
functions_zip_path="$repo_root/.deploy/lp11/functions/functions.zip"

if [[ -n "$app_insights_component_name" ]]; then
  app_insights_name="$app_insights_component_name"
else
  app_insights_name="$(az resource list \
    --resource-group "$resource_group_name" \
    --resource-type "microsoft.insights/components" \
    --query "[0].name" \
    -o tsv)"
fi

if [[ -z "$app_insights_name" ]]; then
  echo "Could not find an existing Application Insights component in '$resource_group_name'."
  exit 1
fi

app_insights_connection_string="$(az resource show \
  --name "$app_insights_name" \
  --resource-group "$resource_group_name" \
  --resource-type "microsoft.insights/components" \
  --query "properties.ConnectionString" \
  -o tsv)"

if [[ -z "$app_insights_connection_string" ]]; then
  app_insights_connection_string="$(az resource show \
    --name "$app_insights_name" \
    --resource-group "$resource_group_name" \
    --resource-type "microsoft.insights/components" \
    --query "properties.connectionString" \
    -o tsv)"
fi

if [[ -z "$app_insights_connection_string" ]]; then
  echo "Could not read connection string from Application Insights '$app_insights_name'."
  exit 1
fi

key_vault_uri="$(az keyvault show \
  --name "$key_vault_name" \
  --resource-group "$resource_group_name" \
  --query properties.vaultUri \
  -o tsv)"

az webapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --settings \
  APPLICATIONINSIGHTS_CONNECTION_STRING="$app_insights_connection_string" \
  ApplicationInsights__ConnectionString="$app_insights_connection_string" \
  ApplicationInsights__EnableAdaptiveSampling=false \
  WEBSITE_CLOUD_ROLENAME=conferencehub-web \
  KeyVaultTelemetry__VaultUri="$key_vault_uri" \
  KeyVaultTelemetry__ProbeSecretName="$kv_secret_cosmos_key_name"

az functionapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$function_app_name" \
  --settings \
  APPLICATIONINSIGHTS_CONNECTION_STRING="$app_insights_connection_string" \
  AzureFunctionsJobHost__logging__applicationInsights__samplingSettings__isEnabled=false \
  WEBSITE_CLOUD_ROLENAME=conferencehub-functions

container_app_exists="$(az webapp list \
  --resource-group "$resource_group_name" \
  --query "[?name=='${container_web_app_name}'].name | [0]" \
  -o tsv)"

if [[ -n "$container_app_exists" ]]; then
  az webapp config appsettings set \
    --resource-group "$resource_group_name" \
    --name "$container_web_app_name" \
    --settings \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$app_insights_connection_string" \
    ApplicationInsights__ConnectionString="$app_insights_connection_string" \
    ApplicationInsights__EnableAdaptiveSampling=false \
    WEBSITE_CLOUD_ROLENAME=conferencehub-container \
    KeyVaultTelemetry__VaultUri="$key_vault_uri" \
    KeyVaultTelemetry__ProbeSecretName="$kv_secret_cosmos_key_name"
fi

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

az functionapp restart \
  --resource-group "$resource_group_name" \
  --name "$function_app_name"

az webapp restart \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

if [[ -n "$container_app_exists" ]]; then
  az webapp restart \
    --resource-group "$resource_group_name" \
    --name "$container_web_app_name"
fi

if [[ "-e" != "1" ]]; then
az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"
fi

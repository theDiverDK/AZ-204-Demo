#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

random="${random:-49152}"
location="${location:-swedencentral}"
resource_group_name="${resource_group_name:-rg-conferencehub}"
app_service_plan_name="${app_service_plan_name:-plan-conferencehub}"
app_service_plan_sku="${app_service_plan_sku:-P0V3}"
web_app_name="${web_app_name:-app-conferencehub-${random}}"
runtime="${runtime:-${web_runtime:-DOTNETCORE:9.0}}"

project_dir="$repo_root/ConferenceHub"
publish_dir="$project_dir/publish"
package_path="$project_dir/app.zip"

az group create \
  --name "$resource_group_name" \
  --location "$location"

if ! az appservice plan show --name "$app_service_plan_name" --resource-group "$resource_group_name" >/dev/null 2>&1; then
  az appservice plan create \
    --name "$app_service_plan_name" \
    --resource-group "$resource_group_name" \
    --location "$location" \
    --is-linux \
    --sku "$app_service_plan_sku"
fi

if ! az webapp show --name "$web_app_name" --resource-group "$resource_group_name" >/dev/null 2>&1; then
  az webapp create \
    --name "$web_app_name" \
    --resource-group "$resource_group_name" \
    --plan "$app_service_plan_name" \
    --runtime "$runtime"
fi

az webapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --settings \
  ASPNETCORE_ENVIRONMENT=Production \
  WEBSITE_RUN_FROM_PACKAGE=1 \
  API_MODE=none \
  FUNCTIONS_BASE_URL= \
  AzureFunctions__SendConfirmationUrl= \
  AzureFunctions__FunctionKey=

dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$publish_dir"

rm -f "$package_path"
(cd "$publish_dir" && zip -qr "$package_path" .)

az webapp deploy \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --src-path "$package_path" \
  --type zip

az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"

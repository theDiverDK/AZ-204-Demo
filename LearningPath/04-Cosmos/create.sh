#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

project_dir="$repo_root/ConferenceHub"
publish_dir="$project_dir/publish"
package_path="$project_dir/app.zip"

cosmos_endpoint=""
cosmos_key=""

# LP4 assumes LP1, LP2 and LP3 are already completed.
# Create new Cosmos resources and update existing Web App settings.
az cosmosdb create \
  --name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --locations regionName="$location" failoverPriority=0 isZoneRedundant=False \
  --default-consistency-level Session

az cosmosdb sql database create \
  --account-name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --name "$cosmos_database_name"

az cosmosdb sql container create \
  --account-name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --database-name "$cosmos_database_name" \
  --name "$cosmos_sessions_container_name" \
  --partition-key-path "$cosmos_sessions_partition_key" \
  --throughput 400

az cosmosdb sql container create \
  --account-name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --database-name "$cosmos_database_name" \
  --name "$cosmos_registrations_container_name" \
  --partition-key-path "$cosmos_registrations_partition_key" \
  --throughput 400

cosmos_endpoint="$(az cosmosdb show \
  --name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --query "documentEndpoint" \
  -o tsv)"

cosmos_key="$(az cosmosdb keys list \
  --name "$cosmos_account_name" \
  --resource-group "$resource_group_name" \
  --query "primaryMasterKey" \
  -o tsv)"

az webapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --settings \
  ASPNETCORE_ENVIRONMENT=Development \
  WEBSITE_RUN_FROM_PACKAGE=1 \
  API_MODE=functions \
  FUNCTIONS_BASE_URL="https://${function_app_name}.azurewebsites.net" \
  CosmosDb__Endpoint="$cosmos_endpoint" \
  CosmosDb__Key="$cosmos_key" \
  CosmosDb__DatabaseName="$cosmos_database_name" \
  CosmosDb__SessionsContainerName="$cosmos_sessions_container_name" \
  CosmosDb__RegistrationsContainerName="$cosmos_registrations_container_name"

# --------------------

dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$publish_dir"

rm -f "$package_path"
(cd "$publish_dir" && zip -qr "$package_path" .)

az webapp deploy \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --src-path "$package_path" \
  --type zip

if [[ "${NO_BROWSE:-0}" != "1" ]]; then
az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"
fi

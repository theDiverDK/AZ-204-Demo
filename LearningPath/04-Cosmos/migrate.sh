#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

data_file="$repo_root/ConferenceHub/Data/sessions.json"
migrator_project="$script_dir/CosmosMigrator/CosmosMigrator.csproj"

if [[ ! -f "$data_file" ]]; then
  echo "ERROR: Sessions seed file not found: $data_file"
  exit 1
fi

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

dotnet run --project "$migrator_project" -- \
  "$data_file" \
  "$cosmos_endpoint" \
  "$cosmos_key" \
  "$cosmos_database_name" \
  "$cosmos_sessions_container_name"

echo "Migration complete. Sessions inserted into Cosmos."

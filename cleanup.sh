#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/tools/variables.sh"

key_vault_name="kv-conferencehub-${random}"
app_config_name="appcs-conferencehub-${random}"

echo "Deleting resource group: $resource_group_name"
az group delete \
  --name "$resource_group_name" \
  --yes \
  --no-wait

echo "Waiting for resource group deletion to finish..."
az group wait \
  --name "$resource_group_name" \
  --deleted

echo "Purging soft-deleted Key Vault (if present): $key_vault_name"
for attempt in {1..30}; do
  if az keyvault list-deleted --query "[?name=='$key_vault_name'] | length(@)" -o tsv | grep -q '^1$'; then
    az keyvault purge \
      --name "$key_vault_name" \
      --location "$location"
    break
  fi

  if [[ "$attempt" -eq 30 ]]; then
    echo "Key Vault '$key_vault_name' was not found in soft-deleted state. Skipping purge."
    break
  fi

  echo "Key Vault not visible in deleted list yet (attempt $attempt/30). Waiting 10s..."
  sleep 10
done

echo "Purging soft-deleted App Configuration (if present): $app_config_name"
if az appconfig list-deleted --query "[?name=='$app_config_name'] | length(@)" -o tsv | grep -q '^1$'; then
  az appconfig purge \
    --name "$app_config_name" \
    --location "$location" \
    --yes
fi

echo "Cleanup complete."

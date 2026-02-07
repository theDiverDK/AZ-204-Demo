#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

acr_login_server=""
acr_username=""
acr_password=""
image_name=""

# LP5 assumes LP1-LP4 are already completed.
# Create only container-related resources and deploy ConferenceHub as a container image.
az appservice plan create \
  --name "$container_app_service_plan_name" \
  --resource-group "$resource_group_name" \
  --location "$location" \
  --is-linux \
  --sku "$container_app_service_plan_sku"

az acr create \
  --name "$acr_name" \
  --resource-group "$resource_group_name" \
  --location "$location" \
  --sku "$acr_sku" \
  --admin-enabled true

acr_login_server="$(az acr show --name "$acr_name" --resource-group "$resource_group_name" --query "loginServer" -o tsv)"
image_name="${acr_login_server}/${acr_image_repository}:${acr_image_tag}"

acr_username="$(az acr credential show --name "$acr_name" --resource-group "$resource_group_name" --query "username" -o tsv)"
acr_password="$(az acr credential show --name "$acr_name" --resource-group "$resource_group_name" --query "passwords[0].value" -o tsv)"

docker login "$acr_login_server" --username "$acr_username" --password "$acr_password"

docker buildx build \
  --platform linux/amd64 \
  --file "$repo_root/ConferenceHub/Dockerfile" \
  --tag "$image_name" \
  --push \
  "$repo_root"

az webapp create \
  --resource-group "$resource_group_name" \
  --plan "$container_app_service_plan_name" \
  --name "$container_web_app_name" \
  --deployment-container-image-name "$image_name"

az webapp config container set \
  --resource-group "$resource_group_name" \
  --name "$container_web_app_name" \
  --container-image-name "$image_name" \
  --container-registry-url "https://${acr_login_server}" \
  --container-registry-user "$acr_username" \
  --container-registry-password "$acr_password"

az webapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$container_web_app_name" \
  --settings \
  ASPNETCORE_ENVIRONMENT=Production \
  WEBSITES_PORT=8080

az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$container_web_app_name"

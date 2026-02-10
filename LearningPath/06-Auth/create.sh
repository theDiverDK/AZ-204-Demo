#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
source "$repo_root/tools/variables.sh"

current_user_upn=""
current_user_id=""
tenant_id=""
tenant_domain=""
user_upn=""
organizer_upn=""
web_redirect_uri=""
app_id=""
sp_id=""
client_secret=""
user_id=""
organizer_id=""
existing_assignment_id=""
project_dir="$repo_root/ConferenceHub"
publish_dir="$repo_root/.deploy/lp06/publish"
package_path="$repo_root/.deploy/lp06/app.zip"

current_user_upn="$(az ad signed-in-user show --query userPrincipalName -o tsv)"
current_user_id="$(az ad signed-in-user show --query id -o tsv)"
tenant_id="$(az account show --query tenantId -o tsv)"
tenant_domain="${current_user_upn#*@}"

user_upn="${entra_demo_user_alias}.${random}@${tenant_domain}"
organizer_upn="${entra_demo_organizer_alias}.${random}@${tenant_domain}"
web_redirect_uri="https://${web_app_name}.azurewebsites.net/signin-oidc"

app_id="$(az ad app list --display-name "$entra_app_registration_name" --query "[0].appId" -o tsv)"
if [[ -z "$app_id" ]]; then
  app_id="$(az ad app create \
    --display-name "$entra_app_registration_name" \
    --sign-in-audience AzureADMyOrg \
    --web-redirect-uris "$web_redirect_uri" \
    --enable-id-token-issuance true \
    --query appId -o tsv)"
fi

az ad app update \
  --id "$app_id" \
  --sign-in-audience AzureADMyOrg \
  --web-redirect-uris "$web_redirect_uri" \
  --enable-id-token-issuance true

app_roles_file="$(mktemp)"
cat > "$app_roles_file" <<JSON
[
  {
    "allowedMemberTypes": ["User"],
    "description": "ConferenceHub attendee role.",
    "displayName": "User",
    "id": "${entra_user_role_id}",
    "isEnabled": true,
    "origin": "Application",
    "value": "${entra_user_role_value}"
  },
  {
    "allowedMemberTypes": ["User"],
    "description": "ConferenceHub organizer role.",
    "displayName": "Organizer",
    "id": "${entra_organizer_role_id}",
    "isEnabled": true,
    "origin": "Application",
    "value": "${entra_organizer_role_value}"
  }
]
JSON

az ad app update --id "$app_id" --app-roles "@$app_roles_file"
rm -f "$app_roles_file"

sp_id="$(az ad sp list --filter "appId eq '$app_id'" --query "[0].id" -o tsv)"
if [[ -z "$sp_id" ]]; then
  az ad sp create --id "$app_id"
  sp_id="$(az ad sp list --filter "appId eq '$app_id'" --query "[0].id" -o tsv)"
fi

user_id="$(az ad user list --filter "userPrincipalName eq '$user_upn'" --query "[0].id" -o tsv)"
if [[ -z "$user_id" ]]; then
  az ad user create \
    --display-name "$entra_demo_user_display_name" \
    --user-principal-name "$user_upn" \
    --password "$entra_demo_user_password"
  user_id="$(az ad user list --filter "userPrincipalName eq '$user_upn'" --query "[0].id" -o tsv)"
fi

organizer_id="$(az ad user list --filter "userPrincipalName eq '$organizer_upn'" --query "[0].id" -o tsv)"
if [[ -z "$organizer_id" ]]; then
  az ad user create \
    --display-name "$entra_demo_organizer_display_name" \
    --user-principal-name "$organizer_upn" \
    --password "$entra_demo_organizer_password"
  organizer_id="$(az ad user list --filter "userPrincipalName eq '$organizer_upn'" --query "[0].id" -o tsv)"
fi

existing_assignment_id="$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/${user_id}/appRoleAssignments" --query "value[?resourceId=='${sp_id}' && appRoleId=='${entra_user_role_id}'] | [0].id" -o tsv)"
if [[ -z "$existing_assignment_id" ]]; then
  az rest \
    --method POST \
    --uri "https://graph.microsoft.com/v1.0/users/${user_id}/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --body "{\"principalId\":\"${user_id}\",\"resourceId\":\"${sp_id}\",\"appRoleId\":\"${entra_user_role_id}\"}"
fi

existing_assignment_id="$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/${organizer_id}/appRoleAssignments" --query "value[?resourceId=='${sp_id}' && appRoleId=='${entra_organizer_role_id}'] | [0].id" -o tsv)"
if [[ -z "$existing_assignment_id" ]]; then
  az rest \
    --method POST \
    --uri "https://graph.microsoft.com/v1.0/users/${organizer_id}/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --body "{\"principalId\":\"${organizer_id}\",\"resourceId\":\"${sp_id}\",\"appRoleId\":\"${entra_organizer_role_id}\"}"
fi

existing_assignment_id="$(az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/${current_user_id}/appRoleAssignments" --query "value[?resourceId=='${sp_id}' && appRoleId=='${entra_organizer_role_id}'] | [0].id" -o tsv)"
if [[ -z "$existing_assignment_id" ]]; then
  az rest \
    --method POST \
    --uri "https://graph.microsoft.com/v1.0/users/${current_user_id}/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --body "{\"principalId\":\"${current_user_id}\",\"resourceId\":\"${sp_id}\",\"appRoleId\":\"${entra_organizer_role_id}\"}"
fi

client_secret="$(az ad app credential reset \
  --id "$app_id" \
  --append \
  --display-name "lp06-auth" \
  --years 2 \
  --query password -o tsv)"

az webapp config appsettings set \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --settings \
  ASPNETCORE_FORWARDEDHEADERS_ENABLED=true \
  AzureAd__Instance="https://login.microsoftonline.com/" \
  AzureAd__TenantId="$tenant_id" \
  AzureAd__ClientId="$app_id" \
  AzureAd__ClientSecret="$client_secret" \
  AzureAd__CallbackPath="/signin-oidc"

# --------------------

rm -rf "$publish_dir"
mkdir -p "$publish_dir"

dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$publish_dir"

rm -f "$package_path"
(cd "$publish_dir" && zip -qr "$package_path" .)

az webapp deploy \
  --resource-group "$resource_group_name" \
  --name "$web_app_name" \
  --src-path "$package_path" \
  --type zip

if [[ "-e" != "1" ]]; then
az webapp browse \
  --resource-group "$resource_group_name" \
  --name "$web_app_name"
fi

echo "Created demo users:"
echo "- ${user_upn} (role: ${entra_user_role_value})"
echo "- ${organizer_upn} (role: ${entra_organizer_role_value})"
echo "Assigned organizer role to signed-in user: ${current_user_upn}"

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"

$current_user_upn = (az ad signed-in-user show --query userPrincipalName -o tsv).Trim()
$current_user_id = (az ad signed-in-user show --query id -o tsv).Trim()
$tenant_id = (az account show --query tenantId -o tsv).Trim()
$tenant_domain = ($current_user_upn -split '@')[-1]

$user_upn = "$entra_demo_user_alias.$random@$tenant_domain"
$organizer_upn = "$entra_demo_organizer_alias.$random@$tenant_domain"
$web_redirect_uri = "https://$web_app_name.azurewebsites.net/signin-oidc"

$app_id = (az ad app list --display-name "$entra_app_registration_name" --query "[0].appId" -o tsv).Trim()
if ([string]::IsNullOrEmpty($app_id)) {
    $app_id = (az ad app create --display-name "$entra_app_registration_name" --sign-in-audience AzureADMyOrg --web-redirect-uris "$web_redirect_uri" --enable-id-token-issuance true --query appId -o tsv).Trim()
}

az ad app update --id "$app_id" --sign-in-audience AzureADMyOrg --web-redirect-uris "$web_redirect_uri" --enable-id-token-issuance true

$app_roles_file = Join-Path ([System.IO.Path]::GetTempPath()) ("app-roles-" + [guid]::NewGuid().ToString() + ".json")
$appRolesJson = @"
[
  {
    "allowedMemberTypes": ["User"],
    "description": "ConferenceHub attendee role.",
    "displayName": "User",
    "id": "$entra_user_role_id",
    "isEnabled": true,
    "origin": "Application",
    "value": "$entra_user_role_value"
  },
  {
    "allowedMemberTypes": ["User"],
    "description": "ConferenceHub organizer role.",
    "displayName": "Organizer",
    "id": "$entra_organizer_role_id",
    "isEnabled": true,
    "origin": "Application",
    "value": "$entra_organizer_role_value"
  }
]
"@
Set-Content -Path $app_roles_file -Value $appRolesJson -Encoding UTF8
az ad app update --id "$app_id" --app-roles "@$app_roles_file"
Remove-Item -Force $app_roles_file

$sp_id = (az ad sp list --filter "appId eq '$app_id'" --query "[0].id" -o tsv).Trim()
if ([string]::IsNullOrEmpty($sp_id)) {
    az ad sp create --id "$app_id"
    $sp_id = (az ad sp list --filter "appId eq '$app_id'" --query "[0].id" -o tsv).Trim()
}

$user_id = (az ad user list --filter "userPrincipalName eq '$user_upn'" --query "[0].id" -o tsv).Trim()
if ([string]::IsNullOrEmpty($user_id)) {
    az ad user create --display-name "$entra_demo_user_display_name" --user-principal-name "$user_upn" --password "$entra_demo_user_password"
    $user_id = (az ad user list --filter "userPrincipalName eq '$user_upn'" --query "[0].id" -o tsv).Trim()
}

$organizer_id = (az ad user list --filter "userPrincipalName eq '$organizer_upn'" --query "[0].id" -o tsv).Trim()
if ([string]::IsNullOrEmpty($organizer_id)) {
    az ad user create --display-name "$entra_demo_organizer_display_name" --user-principal-name "$organizer_upn" --password "$entra_demo_organizer_password"
    $organizer_id = (az ad user list --filter "userPrincipalName eq '$organizer_upn'" --query "[0].id" -o tsv).Trim()
}

$existing_assignment_id = (az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/$user_id/appRoleAssignments" --query "value[?resourceId=='$sp_id' && appRoleId=='$entra_user_role_id'] | [0].id" -o tsv).Trim()
if ([string]::IsNullOrEmpty($existing_assignment_id)) {
    az rest --method POST --uri "https://graph.microsoft.com/v1.0/users/$user_id/appRoleAssignments" --headers "Content-Type=application/json" --body "{\"principalId\":\"$user_id\",\"resourceId\":\"$sp_id\",\"appRoleId\":\"$entra_user_role_id\"}"
}

$existing_assignment_id = (az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/$organizer_id/appRoleAssignments" --query "value[?resourceId=='$sp_id' && appRoleId=='$entra_organizer_role_id'] | [0].id" -o tsv).Trim()
if ([string]::IsNullOrEmpty($existing_assignment_id)) {
    az rest --method POST --uri "https://graph.microsoft.com/v1.0/users/$organizer_id/appRoleAssignments" --headers "Content-Type=application/json" --body "{\"principalId\":\"$organizer_id\",\"resourceId\":\"$sp_id\",\"appRoleId\":\"$entra_organizer_role_id\"}"
}

$existing_assignment_id = (az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/$current_user_id/appRoleAssignments" --query "value[?resourceId=='$sp_id' && appRoleId=='$entra_organizer_role_id'] | [0].id" -o tsv).Trim()
if ([string]::IsNullOrEmpty($existing_assignment_id)) {
    az rest --method POST --uri "https://graph.microsoft.com/v1.0/users/$current_user_id/appRoleAssignments" --headers "Content-Type=application/json" --body "{\"principalId\":\"$current_user_id\",\"resourceId\":\"$sp_id\",\"appRoleId\":\"$entra_organizer_role_id\"}"
}

$client_secret = (az ad app credential reset --id "$app_id" --append --display-name "lp06-auth" --years 2 --query password -o tsv).Trim()

az webapp config appsettings set --resource-group "$resource_group_name" --name "$web_app_name" --settings ASPNETCORE_FORWARDEDHEADERS_ENABLED=true AzureAd__Instance="https://login.microsoftonline.com/" AzureAd__TenantId="$tenant_id" AzureAd__ClientId="$app_id" AzureAd__ClientSecret="$client_secret" AzureAd__CallbackPath="/signin-oidc"

# --------------------

$project_dir = "$repo_root/ConferenceHub"
$publish_dir = "$repo_root/.deploy/lp06/publish"
$package_path = "$repo_root/.deploy/lp06/app.zip"

if (Test-Path $publish_dir) { Remove-Item -Recurse -Force $publish_dir }
New-Item -ItemType Directory -Path $publish_dir -Force | Out-Null


dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$publish_dir"

if (Test-Path $package_path) { Remove-Item -Force $package_path }
Compress-Archive -Path (Join-Path $publish_dir '*') -DestinationPath $package_path -Force

az webapp deploy --resource-group "$resource_group_name" --name "$web_app_name" --src-path "$package_path" --type zip

az webapp browse --resource-group "$resource_group_name" --name "$web_app_name"

Write-Host "Created demo users:"
Write-Host "- $user_upn (role: $entra_user_role_value)"
Write-Host "- $organizer_upn (role: $entra_organizer_role_value)"
Write-Host "Assigned organizer role to signed-in user: $current_user_upn"

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$servicebus_connection_string = ""
$slides_storage_key = ""
$slides_storage_connection_string = ""
$key_vault_id = ""
$web_principal_id = ""
$function_principal_id = ""
$role_assignment_id = ""
$existing_topic_name = ""
$existing_subscription_name = ""
$existing_rule_name = ""
$project_dir = "$repo_root/ConferenceHub"
$web_publish_dir = "$repo_root/.deploy/lp10/web/publish"
$web_package_path = "$repo_root/.deploy/lp10/web/app.zip"
$functions_project_path = "$repo_root/$functions_project_dir/$functions_project_name.csproj"
$functions_publish_path = "$repo_root/.deploy/lp10/functions/publish"
$functions_zip_path = "$repo_root/.deploy/lp10/functions/functions.zip"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-ZipFromDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$DestinationZipPath
    )

    if (Test-Path -LiteralPath $DestinationZipPath) {
        Remove-Item -LiteralPath $DestinationZipPath -Force
    }

    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $SourceDirectory,
        $DestinationZipPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )
}

$existing_namespace_name = "$(az servicebus namespace list  --resource-group `"$resource_group_name`"  --query `"[?name=='$servicebus_namespace_name'].name | [0]`"  -o tsv)"
if ([string]::IsNullOrEmpty($existing_namespace_name)) {
    az servicebus namespace create  --name "$servicebus_namespace_name"  --resource-group "$resource_group_name"  --location "$location"  --sku Standard
}
$existing_topic_name = "$(az servicebus topic list  --resource-group `"$resource_group_name`"  --namespace-name `"$servicebus_namespace_name`"  --query `"[?name=='$servicebus_topic_name'].name | [0]`"  -o tsv)"
if ([string]::IsNullOrEmpty($existing_topic_name)) {
    az servicebus topic create  --resource-group "$resource_group_name"  --namespace-name "$servicebus_namespace_name"  --name "$servicebus_topic_name"
}
$existing_subscription_name = "$(az servicebus topic subscription list  --resource-group `"$resource_group_name`"  --namespace-name `"$servicebus_namespace_name`"  --topic-name `"$servicebus_topic_name`"  --query `"[?name=='$servicebus_subscription_name'].name | [0]`"  -o tsv)"
if ([string]::IsNullOrEmpty($existing_subscription_name)) {
    az servicebus topic subscription create  --resource-group "$resource_group_name"  --namespace-name "$servicebus_namespace_name"  --topic-name "$servicebus_topic_name"  --name "$servicebus_subscription_name"
}
$existing_rule_name = "$(az servicebus namespace authorization-rule list  --resource-group `"$resource_group_name`"  --namespace-name `"$servicebus_namespace_name`"  --query `"[?name=='$servicebus_auth_rule_name'].name | [0]`"  -o tsv)"
if ([string]::IsNullOrEmpty($existing_rule_name)) {
    az servicebus namespace authorization-rule create  --resource-group "$resource_group_name"  --namespace-name "$servicebus_namespace_name"  --name "$servicebus_auth_rule_name"  --rights Send Listen
}
$servicebus_connection_string = "$(az servicebus namespace authorization-rule keys list  --resource-group `"$resource_group_name`"  --namespace-name `"$servicebus_namespace_name`"  --name `"$servicebus_auth_rule_name`"  --query primaryConnectionString  -o tsv)"
$slides_storage_key = "$(az storage account keys list  --resource-group `"$resource_group_name`"  --account-name `"$slides_storage_account_name`"  --query `"[0].value`"  -o tsv)"
az storage queue create  --name "$thumbnail_queue_name"  --account-name "$slides_storage_account_name"  --account-key "$slides_storage_key"
$slides_storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=$slides_storage_account_name;AccountKey=$slides_storage_key;EndpointSuffix=core.windows.net"
$key_vault_id = "$(az keyvault list  --resource-group `"$resource_group_name`"  --query `"[?name=='$key_vault_name'].id | [0]`"  -o tsv)"
if ([string]::IsNullOrEmpty($key_vault_id)) {
    Write-Host "Could not find Key Vault '$key_vault_name'. Run LP7 first."
    exit 1
}
az keyvault secret set  --vault-name "$key_vault_name"  --name "$kv_secret_servicebus_connection_string_name"  --value "$servicebus_connection_string"
az keyvault secret set  --vault-name "$key_vault_name"  --name "$kv_secret_slides_connection_string_name"  --value "$slides_storage_connection_string"
$web_principal_id = "$(az webapp identity assign  --resource-group `"$resource_group_name`"  --name `"$web_app_name`"  --query principalId  -o tsv)"
$function_principal_id = "$(az functionapp identity assign  --resource-group `"$resource_group_name`"  --name `"$function_app_name`"  --query principalId  -o tsv)"
$role_assignment_id = "$(az role assignment list --assignee-object-id `"$web_principal_id`" --scope `"$key_vault_id`" --role `"Key Vault Secrets User`" --query `"[0].id`" -o tsv)"
if ([string]::IsNullOrEmpty($role_assignment_id)) {
    az role assignment create  --assignee-object-id "$web_principal_id"  --assignee-principal-type ServicePrincipal  --role "Key Vault Secrets User"  --scope "$key_vault_id"
}
$role_assignment_id = "$(az role assignment list --assignee-object-id `"$function_principal_id`" --scope `"$key_vault_id`" --role `"Key Vault Secrets User`" --query `"[0].id`" -o tsv)"
if ([string]::IsNullOrEmpty($role_assignment_id)) {
    az role assignment create  --assignee-object-id "$function_principal_id"  --assignee-principal-type ServicePrincipal  --role "Key Vault Secrets User"  --scope "$key_vault_id"
}
az webapp config appsettings set  --resource-group "$resource_group_name"  --name "$web_app_name"  --settings  ServiceBus__ConnectionString="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_servicebus_connection_string_name)"  ServiceBus__TopicName="$servicebus_topic_name"  ThumbnailQueue__ConnectionString="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_slides_connection_string_name)"  ThumbnailQueue__QueueName="$thumbnail_queue_name"
try {
    az webapp config appsettings delete  --resource-group "$resource_group_name"  --name "$web_app_name"  --setting-names  ServiceBusConnectionString  ThumbnailQueueConnectionString
} catch {
}
az functionapp config appsettings set  --resource-group "$resource_group_name"  --name "$function_app_name"  --settings  ServiceBusConnection="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_servicebus_connection_string_name)"  ServiceBusTopicName="$servicebus_topic_name"  ServiceBusSubscriptionName="$servicebus_subscription_name"  ThumbnailQueueConnection="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_slides_connection_string_name)"  ThumbnailQueueName="$thumbnail_queue_name"  SlidesStorageConnectionString="@Microsoft.KeyVault(VaultName=$key_vault_name;SecretName=$kv_secret_slides_connection_string_name)"  SlidesContainerName="$slides_container_name"  CONFIRMATION_SENDER_EMAIL="$confirmation_sender_email"
# --------------------
if (Test-Path "$functions_publish_path") { Remove-Item -Recurse -Force "$functions_publish_path" }
New-Item -ItemType Directory -Path "$functions_publish_path" -Force | Out-Null
dotnet publish "$functions_project_path" -c Release -o "$functions_publish_path"
New-ZipFromDirectory -SourceDirectory "$functions_publish_path" -DestinationZipPath "$functions_zip_path"
az functionapp deployment source config-zip  --resource-group "$resource_group_name"  --name "$function_app_name"  --src "$functions_zip_path"
if (Test-Path "$web_publish_dir") { Remove-Item -Recurse -Force "$web_publish_dir" }
New-Item -ItemType Directory -Path "$web_publish_dir" -Force | Out-Null
dotnet publish "$project_dir/ConferenceHub.csproj" -c Release -o "$web_publish_dir"
New-ZipFromDirectory -SourceDirectory "$web_publish_dir" -DestinationZipPath "$web_package_path"
az webapp deploy  --resource-group "$resource_group_name"  --name "$web_app_name"  --src-path "$web_package_path"  --type zip
az functionapp restart  --resource-group "$resource_group_name"  --name "$function_app_name"
az webapp restart  --resource-group "$resource_group_name"  --name "$web_app_name"
az webapp browse  --resource-group "$resource_group_name"  --name "$web_app_name"

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $true
$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo_root = (Resolve-Path (Join-Path $script_dir "../..")).Path
. "$repo_root/tools/variables.ps1"
$acr_login_server = ""
$acr_username = ""
$acr_password = ""
$image_name = ""
$slides_storage_key = ""
$slides_storage_connection_string = ""
$cosmos_endpoint = ""
$cosmos_key = ""
$functions_base_url = "https://$function_app_name.azurewebsites.net"
$functions_send_url = "$functions_base_url/api/SendConfirmation"
$function_key = ""
# LP5 assumes LP1-LP4 are already completed.
# Create only container-related resources and deploy ConferenceHub as a container image.
az appservice plan create  --name "$container_app_service_plan_name"  --resource-group "$resource_group_name"  --location "$location"  --is-linux  --sku "$container_app_service_plan_sku"
az acr create  --name "$acr_name"  --resource-group "$resource_group_name"  --location "$location"  --sku "$acr_sku"  --admin-enabled true
az storage account create  --name "$slides_storage_account_name"  --resource-group "$resource_group_name"  --location "$location"  --sku "$slides_storage_sku"  --kind StorageV2  --allow-blob-public-access true  --min-tls-version TLS1_2
az storage account update  --name "$slides_storage_account_name"  --resource-group "$resource_group_name"  --allow-blob-public-access true
$slides_storage_key = "$(az storage account keys list  --resource-group `"$resource_group_name`"  --account-name `"$slides_storage_account_name`"  --query `"[0].value`"  -o tsv)"
az storage container create  --name "$slides_container_name"  --account-name "$slides_storage_account_name"  --account-key "$slides_storage_key"  --public-access blob
$slides_storage_connection_string = "DefaultEndpointsProtocol=https;AccountName=$slides_storage_account_name;AccountKey=$slides_storage_key;EndpointSuffix=core.windows.net"
$cosmos_endpoint = "$(az cosmosdb show  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query `"documentEndpoint`"  -o tsv)"
$cosmos_key = "$(az cosmosdb keys list  --name `"$cosmos_account_name`"  --resource-group `"$resource_group_name`"  --query `"primaryMasterKey`"  -o tsv)"
$function_key = "$(az functionapp keys list  --resource-group `"$resource_group_name`"  --name `"$function_app_name`"  --query `"functionKeys.$function_key_name`"  -o tsv)"
$acr_login_server = "$(az acr show --name `"$acr_name`" --resource-group `"$resource_group_name`" --query `"loginServer`" -o tsv)"
$image_name = "${acr_login_server}/${acr_image_repository}:$acr_image_tag"
$acr_username = "$(az acr credential show --name `"$acr_name`" --resource-group `"$resource_group_name`" --query `"username`" -o tsv)"
$acr_password = "$(az acr credential show --name `"$acr_name`" --resource-group `"$resource_group_name`" --query `"passwords[0].value`" -o tsv)"
docker login "$acr_login_server" --username "$acr_username" --password "$acr_password"
docker buildx build  --platform linux/amd64  --file "$repo_root/ConferenceHub/Dockerfile"  --tag "$image_name"  --push  "$repo_root"
az webapp create  --resource-group "$resource_group_name"  --plan "$container_app_service_plan_name"  --name "$container_web_app_name"  --deployment-container-image-name "$image_name"
az webapp config container set  --resource-group "$resource_group_name"  --name "$container_web_app_name"  --container-image-name "$image_name"  --container-registry-url "https://$acr_login_server"  --container-registry-user "$acr_username"  --container-registry-password "$acr_password"
az webapp config appsettings set  --resource-group "$resource_group_name"  --name "$container_web_app_name"  --settings  ASPNETCORE_ENVIRONMENT=Development  WEBSITES_PORT=8080  API_MODE=functions  FUNCTIONS_BASE_URL="$functions_base_url"  AzureFunctions__SendConfirmationUrl="$functions_send_url"  AzureFunctions__FunctionKey="$function_key"  SlideStorage__ConnectionString="$slides_storage_connection_string"  SlideStorage__ContainerName="$slides_container_name"  CosmosDb__Endpoint="$cosmos_endpoint"  CosmosDb__Key="$cosmos_key"  CosmosDb__DatabaseName="$cosmos_database_name"  CosmosDb__SessionsContainerName="$cosmos_sessions_container_name"  CosmosDb__RegistrationsContainerName="$cosmos_registrations_container_name"
az webapp browse  --resource-group "$resource_group_name"  --name "$container_web_app_name"

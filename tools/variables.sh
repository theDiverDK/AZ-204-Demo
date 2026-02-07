#!/bin/bash

random=49152
location="swedencentral"

resource_group_name="rg-conferencehub"
app_service_plan_name="plan-conferencehub"
app_service_plan_sku="P0V3"

web_app_name="app-conferencehub-${random}"
web_runtime="DOTNETCORE:9.0"

# LP2 variables
storage_account_name="stconferencehub${random}"
function_app_name="func-conferencehub-${random}"
function_runtime="dotnet-isolated"
function_runtime_version="9"
function_worker_runtime="dotnet-isolated"
function_key_name="default"
confirmation_sender_email="noreply@conferencehub.local"
functions_project_name="ConferenceHub.Functions"
functions_project_dir="LearningPath/02-Functions/ConferenceHub.Functions"
functions_publish_dir="LearningPath/02-Functions/ConferenceHub.Functions/publish"
functions_package_path="LearningPath/02-Functions/ConferenceHub.Functions.zip"

# LP3 variables
slides_storage_account_name="stslideshub${random}"
slides_container_name="session-slides"
slides_storage_sku="Standard_LRS"

# LP4 Cosmos variables
cosmos_account_name="cosmos-conferencehub-${random}"
cosmos_database_name="conferencehub"
cosmos_sessions_container_name="sessions"
cosmos_registrations_container_name="registrations"
cosmos_sessions_partition_key="/id"
cosmos_registrations_partition_key="/partitionKey"

# LP5 container variables
container_app_service_plan_name="plan-conferencehub-container"
container_app_service_plan_sku="P0V3"
container_web_app_name="app-conferencehub-container-${random}"

acr_name="acrconferencehub${random}"
acr_sku="Basic"
acr_image_repository="conferencehub"
acr_image_tag="lp05"

# LP6 Entra ID and auth variables
entra_app_registration_name="appreg-conferencehub-${random}"
entra_user_role_value="User"
entra_organizer_role_value="Organizer"
entra_user_role_id="0f369c13-e9c5-4f09-b707-4e9f0cc2f946"
entra_organizer_role_id="f2942f71-3a3c-43dd-b507-84b6f3e6288f"
entra_demo_user_display_name="ConferenceHub User"
entra_demo_user_alias="user"
entra_demo_user_password="Az204Demo!123"
entra_demo_organizer_display_name="ConferenceHub Organizer"
entra_demo_organizer_alias="organizer"
entra_demo_organizer_password="Az204Demo!123"
container_lp6_image_tag="lp06"

# LP7 Key Vault variables
key_vault_name="kv-conferencehub-${random}"
key_vault_sku="standard"
kv_secret_azuread_client_secret_name="azuread-client-secret"
kv_secret_cosmos_key_name="cosmos-key"
kv_secret_slides_connection_string_name="slides-storage-connection-string"
kv_secret_functions_key_name="functions-key"

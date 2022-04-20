provider "azurerm" {
    features {}
}

#[gst] - work out better method of container/key sharing across builds
terraform {
  backend "azurerm" {                           
      resource_group_name = "tf_rg_blobstore"
      storage_account_name = "tfstorageaccountgtinney"
      container_name = "tfstatefnapp"
      key = "terraform.tfstate"
  }
}   

resource "azurerm_resource_group" "resource_group" {
  name = "${var.project}-${var.environment}-resource-group"
  location = var.location
}

resource "azurerm_storage_account" "storage_account" {
  name = "${var.project}${var.environment}storage"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_application_insights" "application_insights" {
  name                = "${var.project}-${var.environment}-application-insights"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  application_type    = "web"
}

#todo - `azurerm_app_service_plan` resource has been superseded by the `azurerm_service_plan` resource.
resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "${var.project}-${var.environment}-app-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = var.location
  kind                = "FunctionApp"
  sku {
    tier = "Standard"
    size = "S1"
  }
}

# azurerm_function_app deprecated in tf 3.0, replaced by azurerm_windows_function_app
resource "azurerm_function_app" "function_app" {
  name                       = "${var.project}-${var.environment}-function-app"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = var.location
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1",
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet",
    "AzureWebJobsDisableHomepage" = "true",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.application_insights.instrumentation_key,
  }
  site_config {
    use_32_bit_worker_process = true
    always_on = true
    dotnet_framework_version = "v6.0"
  }
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~4"

  #need below?
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

resource "azurerm_function_app_slot" "function_app_slot" {
  name                       = "${var.project}-${var.environment}-function-app-staging"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = var.location
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  function_app_name          = azurerm_function_app.function_app.name
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE" = "1",
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet",
    "AzureWebJobsDisableHomepage" = "true",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.application_insights.instrumentation_key,
  }
  site_config {
    use_32_bit_worker_process = true
    always_on = true
    dotnet_framework_version = "v6.0"
  }
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~4"

  #need below?
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}


#output "function_app_name" {
#  value = azurerm_function_app.function_app.name#
#  description = "Deployed function app name"
#}

#output "function_app_default_hostname" {
#  value = azurerm_function_app.function_app.default_hostname
#  description = "Deployed function app hostname"
#}
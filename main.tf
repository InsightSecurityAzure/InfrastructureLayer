variable "Version" {}

variable "location" {
  type                      = string
  default                   = "East US"
}


# PROVIDERS

provider "azurerm" {
  features {}
}


# RESOURCES
resource "azurerm_resource_group" "ServiceLayer" {
    name                    = "FrontendServices"
    location                = var.location
}

resource "azurerm_resource_group" "BackendDB" {
    name                    = "Backend"
    location                = var.location
}

resource "azurerm_resource_group" "MonitoringResource" {
    name                    = "MonitoringResource"
    location                = var.location
}

resource "azurerm_cosmosdb_account" "db" {
    name                    = "backendservices-insightsecurity-cis95216"
    location                = var.location
    resource_group_name     = azurerm_resource_group.BackendDB.name
    offer_type              = "Standard"
    kind                    = "GlobalDocumentDB"

    enable_automatic_failover = false

    consistency_policy {
        consistency_level = "Session"
        max_interval_in_seconds = 5
        max_staleness_prefix    = 100
    }

    geo_location {
        prefix            = "backendservices-insightsecurity-cis952162"
        location          = var.location
        failover_priority = 0
    }
}

resource "azurerm_application_insights" "AppInsights" {
  name                = "insight-security-appinsights"
  location            = var.location
  resource_group_name = azurerm_resource_group.MonitoringResource.name
  application_type    = "web"
}

resource "azurerm_storage_account" "FrontendServiceStorage" {
    name                    = "frontendservicestorage"
    resource_group_name     = azurerm_resource_group.ServiceLayer.name
    location                = var.location
    account_tier            = "Standard"
    account_replication_type= "LRS"
}

resource "azurerm_app_service_plan" "aspfrontservice" {
    name                    = "frontend-service-plan"
    location                = var.location
    resource_group_name     = azurerm_resource_group.ServiceLayer.name
    kind                    = "FunctionApp"

    sku {
        tier = "Dynamic"
        size = "Y1"
    }
}

resource "azurerm_function_app" "frontendservice" {
    name                      = "frontendservice-v-${var.Version}"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.ServiceLayer.name
    app_service_plan_id       = azurerm_app_service_plan.aspfrontservice.id
    storage_connection_string = azurerm_storage_account.FrontendServiceStorage.primary_connection_string
    
    app_settings = {
         ciscosmosdb_DOCUMENTDB = azurerm_cosmosdb_account.db.connection_strings[0]
         APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.AppInsights.instrumentation_key
    }
}
resource "azurerm_storage_account" "main" {
  name                     = "st${var.basename}"
  location                 = var.location
  resource_group_name      = var.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "main" {
  name                = "plan-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  kind                = "FunctionApp"
  reserved            = true

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "main" {
  name                       = "func-${var.basename}"
  location                   = var.location
  resource_group_name        = var.resource_group
  app_service_plan_id        = azurerm_app_service_plan.main.id
  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key
  https_only                 = true
  version                    = "~3"
  os_type                    = "linux"
  app_settings = merge({
    FUNCTIONS_WORKER_RUNTIME       = "dotnet"
    APPINSIGHTS_INSTRUMENTATIONKEY = var.instrumentation_key
  }, var.appsettings)
  identity {
    type = "SystemAssigned"
  }
}

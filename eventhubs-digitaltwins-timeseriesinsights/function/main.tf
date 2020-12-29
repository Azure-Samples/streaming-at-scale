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
    WEBSITE_RUN_FROM_PACKAGE       = "" # Must be present for ignore_changes to work
    WEBSITE_USE_ZIP                = "" # Must be present for ignore_changes to work
  }, var.appsettings)
  identity {
    type = "SystemAssigned"
  }

  # Ignore blob URLs set by "func azure functionapp publish" 
  lifecycle { ignore_changes = [
    app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    app_settings["WEBSITE_USE_ZIP"],
  ] }
}

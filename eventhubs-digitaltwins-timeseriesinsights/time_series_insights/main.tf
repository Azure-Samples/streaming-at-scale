resource "azurerm_storage_account" "time_series_insights" {
  name                     = "st${var.basename}tsi"
  location                 = var.location
  resource_group_name      = var.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_iot_time_series_insights_gen2_environment" "main" {
  name                = "tsi-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  sku_name            = "L1"
  id_properties       = ["id"]
  storage {
    name = azurerm_storage_account.time_series_insights.name
    key  = azurerm_storage_account.time_series_insights.primary_access_key
  }
}

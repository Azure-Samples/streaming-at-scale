resource "azurerm_storage_account" "time_series_insights" {
  name                     = "st${var.basename}tsi"
  location                 = var.location
  resource_group_name      = var.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_digital_twins_instance" "main" {
  name                = "dt-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_digital_twins_endpoint_eventhub" "main" {
  name                                 = "EventHub"
  digital_twins_id                     = azurerm_digital_twins_instance.main.id
  eventhub_primary_connection_string   = var.eventhub_primary_connection_string
  eventhub_secondary_connection_string = var.eventhub_secondary_connection_string
}

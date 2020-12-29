resource "azurerm_iothub" "main" {
  name                = "iot-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group

  sku {
    name     = "S1"
    capacity = var.capacity
  }

  event_hub_partition_count = var.partition_count
  event_hub_retention_in_days = 1
}

resource "azurerm_iothub" "main" {
  name                = "iot-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group

  sku {
    name     = var.sku
    capacity = var.capacity
  }

  event_hub_partition_count   = var.partition_count
  event_hub_retention_in_days = 1

  fallback_route {
    enabled        = true
    endpoint_names = ["events"]
  }
}

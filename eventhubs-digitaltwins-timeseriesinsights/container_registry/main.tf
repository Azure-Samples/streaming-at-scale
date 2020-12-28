resource "azurerm_container_registry" "main" {
  name                = "acr${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Basic"
  admin_enabled       = true
}

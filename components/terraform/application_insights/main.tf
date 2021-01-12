resource "azurerm_application_insights" "main" {
  name                = "appi-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  application_type    = "web"
}

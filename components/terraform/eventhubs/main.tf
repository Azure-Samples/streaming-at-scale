resource "azurerm_eventhub_namespace" "main" {
  name                = "evh-${var.basename}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Standard"
  capacity            = var.capacity
}

resource "azurerm_eventhub" "main" {
  name                = "ingestion"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group
  partition_count     = var.partition_count
  message_retention   = 1
}

resource "azurerm_eventhub_authorization_rule" "listen" {
  name                = "Listen"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.main.name
  resource_group_name = var.resource_group
  listen              = true
  send                = false
  manage              = false
}

resource "azurerm_eventhub_authorization_rule" "send" {
  name                = "Send"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.main.name
  resource_group_name = var.resource_group
  listen              = false
  send                = true
  manage              = false
}

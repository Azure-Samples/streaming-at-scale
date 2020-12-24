resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location
}

module "eventhubs" {
  source         = "./eventhubs"
  basename       = "${var.appname}eh"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "time_series_insights" {
  source         = "./time_series_insights"
  basename       = "${var.appname}tsi"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "function" {
  source         = "./function"
  basename       = "${var.appname}fun"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  source_path    = abspath("StreamingProcessor-DigitalTwins/StreamingProcessor-CosmosDB/")
}

module "digital_twins" {
  source                               = "./digital_twins"
  basename                             = "${var.appname}dt"
  resource_group                       = azurerm_resource_group.main.name
  location                             = azurerm_resource_group.main.location
  eventhub_primary_connection_string   = module.eventhubs.send_primary_connection_string
  eventhub_secondary_connection_string = module.eventhubs.send_secondary_connection_string
}

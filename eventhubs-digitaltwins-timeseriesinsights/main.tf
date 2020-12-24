# Provides client_id, tenant_id, subscription_id and object_id variables
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group
  location = var.location
}

module "application_insights" {
  source         = "./application_insights"
  basename       = var.appname
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "simulator" {
  source                    = "./simulator"
  basename                  = var.appname
  resource_group            = azurerm_resource_group.main.name
  location                  = azurerm_resource_group.main.location
  eventhub_connectionstring = module.eventhubs_in.send_primary_connection_string
}

module "eventhubs_in" {
  source         = "./eventhubs"
  basename       = "${var.appname}in"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "function_adt" {
  source              = "./function"
  basename            = "${var.appname}in"
  resource_group      = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  source_path         = abspath("functions/EventHubToDigitalTwins")
  instrumentation_key = module.application_insights.instrumentation_key
  appsettings = {
    ADT_SERVICE_URL = module.digital_twins.service_url
    EVENT_HUB       = module.eventhubs_in.listen_primary_connection_string
  }

}

module "digital_twins" {
  source                               = "./digital_twins"
  basename                             = "${var.appname}dt"
  resource_group                       = azurerm_resource_group.main.name
  location                             = azurerm_resource_group.main.location
  eventhub_primary_connection_string   = module.eventhubs_adt.send_primary_connection_string
  eventhub_secondary_connection_string = module.eventhubs_adt.send_secondary_connection_string
}

module "eventhubs_adt" {
  source         = "./eventhubs"
  basename       = "${var.appname}dt"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "function_tsi" {
  source              = "./function"
  basename            = "${var.appname}ts"
  resource_group      = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  source_path         = abspath("functions/DigitalTwinsToTSI")
  instrumentation_key = module.application_insights.instrumentation_key

  appsettings = {
    EVENT_HUB_ADT   = module.eventhubs_adt.listen_primary_connection_string
    EVENT_HUB_TSI   = module.eventhubs_tsi.send_primary_connection_string
  }
}

module "eventhubs_tsi" {
  source         = "./eventhubs"
  basename       = "${var.appname}ts"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "time_series_insights" {
  source                     = "./time_series_insights"
  basename                   = var.appname
  resource_group             = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  reader_principal_object_id = data.azurerm_client_config.current.object_id
}

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

module "container_registry" {
  source         = "./container_registry"
  basename       = var.appname
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "simulator" {
  source                  = "./simulator"
  basename                = "${var.appname}simulator"
  resource_group          = azurerm_resource_group.main.name
  location                = azurerm_resource_group.main.location
  iothub_connectionstring = module.iothub.send_primary_connection_string
  device_count            = 1000
  interval                = floor(1000000 / var.simulator_events_per_second)
}

module "iothub" {
  source         = "./iothub"
  basename       = "${var.appname}in"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  sku            = var.iothub_sku
  capacity       = var.iothub_capacity
}

module "function_adt" {
  source         = "./function"
  basename       = "${var.appname}in"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  source_path    = abspath("src/EventHubToDigitalTwins")
  tier           = "ElasticPremium"
  sku            = var.function_sku
  workers        = var.function_workers

  instrumentation_key = module.application_insights.instrumentation_key

  appsettings = {
    ADT_SERVICE_URL = module.digital_twins.service_url
    EVENT_HUB       = module.iothub.listen_event_hubs_primary_connection_string
  }
}

resource "azurerm_role_assignment" "main" {
  scope                = module.digital_twins.digital_twins_instance_resource_id
  role_definition_name = "Azure Digital Twins Data Owner"
  principal_id         = module.function_adt.system_assigned_identity.principal_id
}

module "digital_twins" {
  source                               = "./digital_twins"
  basename                             = "${var.appname}dt"
  resource_group                       = azurerm_resource_group.main.name
  location                             = azurerm_resource_group.main.location
  eventhub_primary_connection_string   = module.eventhubs_adt.send_primary_connection_string
  eventhub_secondary_connection_string = module.eventhubs_adt.send_secondary_connection_string
  owner_principal_object_id            = data.azurerm_client_config.current.object_id
}

module "eventhubs_adt" {
  source         = "./eventhubs"
  basename       = "${var.appname}dt"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
}

module "function_tsi" {
  source         = "./function"
  basename       = "${var.appname}ts"
  resource_group = azurerm_resource_group.main.name
  location       = azurerm_resource_group.main.location
  source_path    = abspath("src/DigitalTwinsToTSI")
  tier           = "ElasticPremium"
  sku            = var.function_sku
  workers        = var.function_workers

  instrumentation_key = module.application_insights.instrumentation_key

  appsettings = {
    EVENT_HUB_ADT = module.eventhubs_adt.listen_primary_connection_string
    EVENT_HUB_TSI = module.eventhubs_tsi.send_primary_connection_string
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
  eventhub_namespace_name    = module.eventhubs_tsi.eventhub_namespace_name
  eventhub_name              = module.eventhubs_tsi.eventhub_name
}
